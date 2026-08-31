# 실행 Runbook — 하이브리드 무과금 DevOps 플랫폼 구축
### "무엇을, 어떤 순서로, 어떤 명령으로" 진행하는가

전제 환경
- OCI Ampere A1: `node1`, `node2` (k3s server/agent)
- 홈랩/온프렘: `repository` 노드
- 현재 상태: AWX가 `local-path`(node2 로컬)에 배포됨 / Loki·Grafana 운영 중
- 노드 간: Tailscale 오버레이

> ⚠️ 원칙: **각 Phase는 "사전 팩트 확인 → 작업 → 검증"** 순서로만 진행한다.
> 앞 Phase의 검증이 통과하지 못하면 다음 Phase로 넘어가지 않는다.

---

## Phase 0. 착수 전 팩트 확인 (파괴적 작업 없음, 반드시 먼저)

### 0-1. 노드 정체 확인 (어느 노드가 OCI인가)
```bash
# providerID에 oci://ocid1.instance... 가 있으면 OCI 인스턴스
kubectl get nodes -o custom-columns='NAME:.metadata.name,PROVIDER:.spec.providerID,IP:.status.addresses[?(@.type=="InternalIP")].address'

# 각 노드에서 OCI 메타데이터 응답 여부 (OCI면 응답, 홈랩이면 무응답)
# node1/node2에서:
curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | head
```
✅ 기대: node1/node2 = OCI, repository = 홈랩(무응답). 이 결과로 스토리지 태그를 확정.

### 0-2. 현재 스토리지/워크로드 상태 스냅샷
```bash
kubectl get nodes -o wide
kubectl get sc
kubectl get pv
kubectl get pvc -A
kubectl get pods -n awx -o wide
kubectl get pods -n monitoring -o wide
```
✅ 기대: AWX PVC 2개(`postgres-15-...`, `awx-projects-claim`)가 `local-path`로 node2에 Bound.

### 0-3. OCI 무과금 경계 확인 (작업 전 반드시)
```bash
# 각 OCI 노드 디스크 여유 (Longhorn 데이터 디스크 확보 가능한지)
df -h /
lsblk
```
- OCI 콘솔에서: **Block Volume 총합 ≤ 200GB**, **Ampere A1 ≤ 4 OCPU/24GB** 확인
- **OCI 콘솔 → Budgets** 에서 **$0.01 알람** 먼저 설정 (안전장치를 작업 前에)

### 0-4. 백업 먼저 (가장 중요)
```bash
# AWX PostgreSQL 논리 백업 - 이관 실패 대비 안전망
kubectl exec -n awx awx-postgres-15-0 -- \
  bash -c 'pg_dump -U $POSTGRES_USER -F c $POSTGRES_DB' > awx-preflight-$(date +%F).dump
ls -al awx-preflight-*.dump   # 파일 크기 > 0 확인
```
🚩 **이 백업이 성공하기 전에는 어떤 파괴적 작업도 진행하지 않는다.**

---

## Phase 1. Longhorn 도입 (스토리지 기반 마련)

### 1-1. 모든 노드 사전 요구사항 (node1, node2, repository 전부)
```bash
# open-iscsi 설치 (Longhorn 필수)
# Rocky/RHEL 계열:
sudo dnf install -y iscsi-initiator-utils
sudo systemctl enable --now iscsid
# Ubuntu 계열(홈랩):
# sudo apt-get install -y open-iscsi nfs-common && sudo systemctl enable --now iscsid

# NFS 클라이언트(백업용, 선택)
sudo dnf install -y nfs-utils   # 또는 apt nfs-common
```

### 1-2. 환경 사전점검 스크립트
```bash
curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/master/scripts/environment_check.sh | bash
```
✅ 기대: 모든 노드에서 PASS. FAIL이면 해당 노드 패키지부터 해결.

### 1-3. Longhorn 설치 (Helm)
```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system --create-namespace \
  --set defaultSettings.defaultReplicaCount=2   # 2노드 환경 → 3 대신 2

kubectl -n longhorn-system get pods -w
```
✅ 기대: `longhorn-manager`, `csi-*`, `instance-manager-*` 모두 Running.

### 1-4. Storage Tag 지정 (하이브리드 핵심)
```bash
# Longhorn UI 또는 kubectl로 노드 태그 부여
# OCI 노드:
kubectl -n longhorn-system label nodes node1 node.longhorn.io/create-default-disk=true
kubectl -n longhorn-system annotate node node1 node.longhorn.io/default-node-tags='["oci"]' --overwrite
kubectl -n longhorn-system annotate node node2 node.longhorn.io/default-node-tags='["oci"]' --overwrite
# 홈랩 노드:
kubectl -n longhorn-system annotate node repository node.longhorn.io/default-node-tags='["homelab"]' --overwrite
```
> UI 사용 권장: Longhorn UI → Node → Edit Node and Disks → +New Node Tag (`oci` / `homelab`).

### 1-5. DB 전용 StorageClass 생성 (OCI 노드 고정)
```yaml
# longhorn-oci-sc.yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: longhorn-oci
provisioner: driver.longhorn.io
allowVolumeExpansion: true
parameters:
  numberOfReplicas: "2"
  staleReplicaTimeout: "480"
  nodeSelector: "oci"        # ← OCI 노드에만 replica (WAN 동기복제 회피)
```
```bash
kubectl apply -f longhorn-oci-sc.yaml
kubectl get sc
```
✅ 기대: `longhorn`, `longhorn-oci` StorageClass 존재.

---

## Phase 2. AWX를 local-path → Longhorn 무손실 이관

> 다운타임 허용(사용자가 "다운타임 길어도 됨" 명시). 안전한 논리 백업/복원 방식 사용.

### 2-1. 새 PVC(Longhorn) 준비 & AWX 중단
```bash
# AWX 운영 중단 (operator가 되살리지 않도록 CR 스케일 or operator 스케일)
kubectl -n awx scale deploy awx-operator-controller-manager --replicas=0
kubectl -n awx scale deploy awx-web awx-task --replicas=0
```

### 2-2. Postgres 데이터 이관 (2가지 방법 중 택1)

**방법 A — 논리 백업/복원(권장, 버전 안전)**
```bash
# 0-4에서 뜬 dump를 새 Longhorn PVC 기반 Postgres에 복원
# (AWX CR의 postgres_storage_class 를 longhorn-oci 로 바꿔 재배포 → 빈 DB 생성 후)
kubectl -n awx exec -i <new-postgres-pod> -- \
  bash -c 'pg_restore -U $POSTGRES_USER -d $POSTGRES_DB --clean --if-exists' < awx-preflight-YYYY-MM-DD.dump
```

**방법 B — rsync 파일 복사(디렉터리 통째)**
```bash
# old(local-path) PVC ↔ new(longhorn) PVC 를 한 pod에 동시 마운트 후 cp -a
# data-migrator pod 띄워 cp -a /mnt/old/. /mnt/new/
```

### 2-3. AWX CR이 Longhorn을 쓰도록 변경
```yaml
# AWX CR patch (핵심 필드)
spec:
  postgres_storage_class: longhorn-oci
  postgres_storage_requirements:
    requests:
      storage: 8Gi
  projects_persistence: true
  projects_storage_class: longhorn-oci
```
```bash
kubectl -n awx apply -f awx-cr.yaml
kubectl -n awx scale deploy awx-operator-controller-manager --replicas=1
```

### 2-4. 검증 (node2 장애 시나리오까지)
```bash
kubectl -n awx get pvc            # STORAGECLASS = longhorn-oci, Bound 확인
kubectl -n awx get pods -o wide   # awx-web/awx-task/postgres Running
# 실제 장애 검증: node2를 cordon+drain 하고 pod가 node1에서 뜨는지
kubectl cordon node2
kubectl -n awx delete pod awx-postgres-15-0
kubectl -n awx get pods -o wide   # ← node1에서 재기동되면 성공
kubectl uncordon node2
```
✅ 기대: node2 없이도 AWX Postgres가 node1에서 기동. (기존 local-path에선 불가능했던 부분)

---

## Phase 3. GitOps(ArgoCD) 도입 — 취업 어필 핵심

### 3-1. GitOps repo 구조 만들기 (GitHub, 무료)
```
gitops-repo/
├─ bootstrap/root-app.yaml         # App-of-Apps 루트
├─ apps/{portfolio,awx,addons}/
└─ monitoring/{kube-prometheus-stack,loki}/
     └─ loki/loki-override.yaml    # ★ S3 값 (Phase 4에서 -f로 연결)
```

### 3-2. ArgoCD 설치
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd get pods -w

# 초기 admin 비번
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

### 3-3. App-of-Apps 부트스트랩
```yaml
# bootstrap/root-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<you>/gitops-repo.git
    targetRevision: main
    path: apps
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated: { prune: true, selfHeal: true }
```
```bash
kubectl apply -f bootstrap/root-app.yaml
```
✅ 기대: ArgoCD UI에서 root → 하위 Application들이 Synced/Healthy.

---

## Phase 4. 관측성 + Loki S3 백엔드 (loki-override 버그 정정 반영)

### 4-1. OCI Object Storage 버킷 생성 (무료 20GB 내)
- OCI 콘솔 → Object Storage → Create Bucket (예: `loki-logs`)
- Customer Secret Key 발급(S3 호환 access/secret key) → 네임스페이스 확인

### 4-2. loki-override.yaml (S3 백엔드)
```yaml
# monitoring/loki/loki-override.yaml
loki:
  storage:
    type: s3
    s3:
      endpoint: <namespace>.compat.objectstorage.<region>.oraclecloud.com
      region: <region>
      bucketnames: loki-logs
      access_key_id: <ACCESS_KEY>
      secret_access_key: <SECRET_KEY>
      s3forcepathstyle: true
```

### 4-3. ★ 반드시 -f 로 적용 (이전 문서 3-3 버그 정정)
```bash
# 직접 helm 시:
helm upgrade --install loki grafana/loki -n monitoring \
  -f monitoring/loki/loki-override.yaml

# ArgoCD 관리 시 Application에 명시:
#   source.helm.valueFiles: [ loki-override.yaml ]

# 검증: s3 블록이 실제 반영됐는지
helm get values loki -n monitoring
```
✅ 기대: `helm get values`에 `storage.s3` 블록 출력.

### 4-4. kube-prometheus-stack 배포
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install kps prometheus-community/kube-prometheus-stack -n monitoring
kubectl -n monitoring get pods
```

---

## Phase 5. DevSecOps(Trivy) + 마무리

### 5-1. Trivy-Operator (이미지 취약점 자동 스캔)
```bash
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm upgrade --install trivy-operator aqua/trivy-operator \
  -n trivy-system --create-namespace
kubectl -n trivy-system get pods
# 스캔 결과:
kubectl get vulnerabilityreports -A
```

### 5-2. 백업 타깃 연결 (Longhorn → OCI Object Storage)
- Longhorn UI → Settings → Backup Target = `s3://loki-logs@<region>/backups` (또는 별도 버킷)
- Backup Target Credential Secret 등록(access/secret key)
- 정기 백업 RecurringJob 설정 (증분, 보존기간으로 20GB 통제)

### 5-3. 최종 검증 & 무과금 점검
```bash
kubectl get applications -n argocd     # 전부 Synced/Healthy
kubectl get pods -A | grep -v Running  # 비정상 pod 없음
```
- [ ] Ampere A1 ≤ 4 OCPU / 24GB
- [ ] Block Volume 총합 ≤ 200GB
- [ ] Object Storage ≤ 20GB / 월 API ≤ 50K
- [ ] OCI Monitoring·Logging·Flexible LB **미사용**
- [ ] OCI Budget $0.01 알람 활성

---

## 진행 우선순위 (한눈에)

| 순서 | Phase | 리스크 | 소요(예상) |
|------|-------|--------|-----------|
| 1 | Phase 0 (팩트+백업) | 없음 | 30분 |
| 2 | Phase 1 (Longhorn) | 낮음 | 1시간 |
| 3 | Phase 2 (AWX 이관) | **중(다운타임)** | 1~2시간 |
| 4 | Phase 3 (ArgoCD) | 낮음 | 1시간 |
| 5 | Phase 4 (관측성/Loki S3) | 낮음 | 1시간 |
| 6 | Phase 5 (Trivy/백업/검증) | 낮음 | 1시간 |

> 💡 하루에 다 할 필요 없음. **Phase 0 → 1 → 2**까지가 "node2 장애 내성 확보"라는 실질 목표.
> Phase 3~5는 포트폴리오 완성도(취업 어필)를 위한 단계라 이후 진행해도 무방.

---

## 롤백 안전망
- **Phase 2 이관 실패** → `awx-preflight-*.dump` 로 기존 local-path Postgres에 즉시 복원, operator replicas 되돌림.
- **Longhorn 문제** → local-path SC가 여전히 default이므로 신규 PVC는 local-path로 회귀 가능.
- **ArgoCD selfHeal 오작동** → `syncPolicy.automated` 제거 후 수동 sync로 전환.
