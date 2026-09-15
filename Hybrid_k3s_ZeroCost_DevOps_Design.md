# 하이브리드 k3s 무과금 DevOps 플랫폼 설계안
### "2026 채용시장 핵심 스택" × "OCI Always Free 100% 무과금" 동시 충족

작성 대상: OCI(Ampere A1) + 홈랩/온프렘 하이브리드 k3s 클러스터
목표: 포트폴리오(woojin-world.duckdns.org)를 **취업시장에서 가장 잘 팔리는 스택**으로 구성하되,
      **단 한 푼도 과금되지 않는** 아키텍처로 설계한다.

---

## 0. 설계 2대 원칙

| 원칙 | 내용 |
|------|------|
| **① In-Demand First** | 2026 채용공고에서 실제로 요구하는 스택만 채택 (Kubernetes, GitOps/ArgoCD, IaC, kube-prometheus-stack, Longhorn, DevSecOps) |
| **② Zero-Bill by Design** | 모든 리소스를 OCI Always Free 한도 안에 "설계 단계에서" 가둔다. 유료로 넘어갈 수 있는 경계를 명시적으로 차단 |

---

## 1. 왜 이 스택인가 — 2026 채용시장 근거

채용 데이터 기준 우선순위(수요 높은 순):

1. **Kubernetes / 컨테이너 오케스트레이션** — 2026년 DevOps/SRE의 **1순위 필수 스킬**, 83% 조직이 프로덕션에서 K8s 운영. (이미 k3s 보유 ✔)
2. **GitOps — ArgoCD** — GitOps는 이제 "기본 배포 패턴", K8s 사용자 64% 채택. **ArgoCD가 가장 널리 쓰이는 GitOps 도구**.
3. **IaC — Terraform/OpenTofu + Ansible** — IaC는 차별점이 아니라 "기본 기대치". (AWX 보유 ✔)
4. **관측성 — Prometheus + Grafana + Loki** — 현대 관측성 표준 스택(kube-prometheus-stack). (이미 구축 중 ✔)
5. **DevSecOps — Trivy 등** — 파이프라인에 보안 통합이 표준화.
6. **자체 호스팅 스토리지 — Longhorn** — 클라우드 종속 없이 하이브리드/온프렘에서 상태 저장 워크로드 운영.

> 핵심 메시지: 지금 보유한 자산(k3s, AWX, Loki, Grafana)에 **ArgoCD(GitOps) + Longhorn(스토리지) + Trivy(보안)** 3개만 얹으면
> "채용시장 정면 대응 포트폴리오"가 완성된다. 그리고 이 전부가 무료다.

---

## 2. 전체 아키텍처 (무과금 경계 명시)

```
                    ┌─────────────────────── Git (GitHub, 무료) ───────────────────────┐
                    │  desired state = single source of truth                          │
                    │   ├─ /apps        (ArgoCD Application 매니페스트)                 │
                    │   ├─ /infra       (Terraform/OpenTofu, k8s addon)                │
                    │   └─ /monitoring  (kube-prometheus-stack, loki values)           │
                    └──────────────────────────────┬───────────────────────────────────┘
                                                   │ pull (reconcile)
                                                   ▼
   ┌──────────────────────────── k3s 클러스터 (하이브리드) ────────────────────────────┐
   │                                                                                   │
   │   [OCI Ampere A1 노드]  node1 / node2          [홈랩/온프렘 노드]  repository     │
   │   ├─ ArgoCD (GitOps 컨트롤러) ★신규             ├─ Longhorn 참여 노드            │
   │   ├─ Longhorn (분산 블록 스토리지) ★신규         │   (storage-tag=homelab)        │
   │   │    storage-tag=oci  ← DB replica 여기 고정   └─ 비민감/백업 워크로드          │
   │   ├─ kube-prometheus-stack (Prometheus+Grafana+Alertmanager)                      │
   │   ├─ Loki (로그, S3 백엔드) ← OCI Object Storage(무료 20GB)                        │
   │   ├─ AWX (Ansible 자동화)  ← Longhorn(oci tag) PVC                                 │
   │   ├─ cert-manager (TLS 자동화, DuckDNS)                                            │
   │   ├─ ingress-nginx                                                                │
   │   └─ Trivy-Operator (이미지 취약점 스캔) ★신규                                     │
   │                                                                                   │
   │        노드 간 사설망: Tailscale 오버레이 (무료)                                   │
   └───────────────────────────────────────────────────────────────────────────────────┘
                                                   │ backup (S3 API)
                                                   ▼
              OCI Object Storage (Always Free: 20GB + 50K req/월)
              ├─ Loki 로그 청크 (불변 객체 → S3 최적)
              └─ Longhorn / AWX 백업 타깃
```

---

## 3. OCI Always Free 한도 대비 리소스 예산표 (★무과금 검증)

| 리소스 | Always Free 한도 | 본 설계 사용량 | 여유 | 비고 |
|--------|-----------------|---------------|------|------|
| Ampere A1 OCPU | 4 OCPU / 24GB RAM | node1+node2 = 4 OCPU/24GB | 0 | **정확히 한도 내** (초과 시 과금) |
| Block Volume | **200GB 합계** (boot+block) | boot 47GB×2 + Longhorn 디스크 ~100GB | ~6GB | boot 최소 47GB 주의 |
| Object Storage | **20GB** + 50K API req/월 | Loki+백업 ~15GB 목표 | ~5GB | 보존기간으로 용량 통제 |
| Outbound Egress | **10TB/월** | 포트폴리오 트래픽 «10TB | 대량 | 사실상 무제한 |
| Monitoring | 500M ingest / 1B retrieval | 자체 Prometheus 사용 → OCI 미사용 | - | OCI 관측성 안 씀 |
| Logging | 10GB/월 | 자체 Loki 사용 → OCI 미사용 | - | OCI 로깅 안 씀 |
| Flexible LB | 1개 / 10Mbps | ingress-nginx(hostPort) 사용 → LB 불필요 | - | LB 대신 hostPort로 절약 |

> ⚠️ **과금 방지 3대 레드라인**
> 1. **Ampere A1을 4 OCPU/24GB 초과 생성 금지** (5번째 OCPU부터 유료).
> 2. **Block Volume 총합 200GB 초과 금지** — boot 볼륨(각 47GB)이 이미 94GB를 먹으므로 Longhorn 데이터 디스크는 ~100GB로 제한.
> 3. **Object Storage 20GB / 월 50K API 요청 초과 금지** — Loki 보존기간·압축으로 통제, Longhorn 백업은 증분+주기 조정.

---

## 4. 컴포넌트별 채택 결정 (무료 대안 선택)

| 영역 | 채택 (무료) | 유료로 샐 수 있는 대안 (회피) | 무과금 근거 |
|------|-------------|------------------------------|-------------|
| 오케스트레이션 | **k3s** | (EKS/OKE 관리형은 컨트롤플레인 과금) | 셀프호스트, OCI 컴퓨트는 Free A1 |
| GitOps | **ArgoCD** | Argo 유료 SaaS | 클러스터 내 셀프호스트 |
| IaC | **OpenTofu** (Terraform 오픈 fork) | Terraform Cloud 유료 티어 | CLI 로컬 실행, state는 Git/OCI Object |
| CI | **GitHub Actions** | 유료 러너 | public repo 무료 분 |
| 스토리지 | **Longhorn** | OCI Block CSI (200GB 초과분 과금) | 노드 로컬 디스크 복제, 무료 |
| 관측성 | **kube-prometheus-stack** | Datadog/New Relic(과금) | 셀프호스트 |
| 로그 | **Loki + OCI Object(20GB내)** | 관리형 로깅 | S3 백엔드 무료 한도 내 |
| 보안 | **Trivy-Operator** | 상용 스캐너 | 오픈소스, 클러스터 내 |
| TLS | **cert-manager + DuckDNS** | 유료 인증서 | Let's Encrypt 무료 |
| 사설망 | **Tailscale** | Site-to-Site VPN 장비 | 무료 플랜 |
| 시크릿 | **External Secrets + OCI Vault(무료 20키)** | 상용 secret manager | Vault Always Free 한도 |

---

## 5. 스토리지 설계 (하이브리드 핵심)

### 5.1 Longhorn Storage Tag로 사이트 분리
OCI ↔ 홈랩은 물리적으로 떨어져 있어 **WAN 동기 복제는 DB에 치명적**. 따라서:

- **AWX PostgreSQL / 지연 민감 워크로드** → `nodeSelector: "oci"` 태그 → **OCI 노드 2대 안에서만** replica 배치 (node2 죽어도 node1 복구, WAN 안 넘음)
- **홈랩 repository 노드** → `storage-tag=homelab` → 비민감·백업용
- **크로스사이트 내구성** → 동기복제 대신 **Longhorn 백업(S3 → OCI Object Storage)** 로 확보

```yaml
# StorageClass: OCI 노드 전용 (DB용)
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: longhorn-oci
provisioner: driver.longhorn.io
allowVolumeExpansion: true
parameters:
  numberOfReplicas: "2"          # 2노드 환경 → 3 대신 2
  staleReplicaTimeout: "480"
  nodeSelector: "oci"            # OCI 노드에만 replica
```

### 5.2 무과금 주의
- Longhorn 데이터 디렉터리는 `/var/lib/longhorn` **전용 디스크** 권장(루트 디스크 I/O 경합·DiskPressure 방지). 단, **블록볼륨 총합 200GB 한도** 내에서.
- 모든 노드 `open-iscsi` 설치 후 `environment_check.sh`로 사전 점검.

---

## 6. GitOps 표준 구조 (ArgoCD) — 이 설계의 "취업 어필 포인트"

```
gitops-repo/
├─ apps/
│  ├─ portfolio/          # 포트폴리오 사이트
│  ├─ awx/                # AWX
│  └─ addons/             # cert-manager, ingress, trivy
├─ monitoring/
│  ├─ kube-prometheus-stack/   # values.yaml (Prometheus+Grafana+Alertmanager)
│  └─ loki/
│     └─ loki-override.yaml    # ★ S3 백엔드 값 (아래 7장 반드시 -f로 적용)
└─ bootstrap/
   └─ root-app.yaml            # App-of-Apps 패턴
```

- **App-of-Apps 패턴**: 루트 Application 1개가 나머지 전부를 자동 배포/자기치유(selfHeal).
- Git = 유일한 진실의 원천 → 모든 변경이 커밋 이력·롤백 경로를 가짐(면접에서 바로 설명 가능한 스토리).

---

## 7. (연계) Loki `loki-override.yaml` 적용 버그 수정

> 이전 문서의 3-2에서 `loki-override.yaml`을 **생성**하고, 3-3에서 **적용**하는데
> `helm upgrade` 명령에 `-f`가 빠져 파일이 무시되던 문제. GitOps로 넘어가도 동일 원칙.

```bash
# ❌ (버그) 파일이 무시됨
helm upgrade --install loki grafana/loki -n monitoring

# ✅ (정정) override를 반드시 -f 로 전달
helm upgrade --install loki grafana/loki -n monitoring \
  -f monitoring/loki/loki-override.yaml

# 검증: object_store/s3 블록이 보이면 정상 반영
helm get values loki -n monitoring
```

ArgoCD로 관리 시에는 Application의 `helm.valueFiles`에 명시:
```yaml
source:
  helm:
    valueFiles:
      - loki-override.yaml   # ← 이게 있어야 실제 반영
```

---

## 8. 도입 순서 (Runbook 요약)

1. **Longhorn 설치** → open-iscsi 점검 → Storage Tag(oci/homelab) 설정 → StorageClass 생성
2. **local-path → Longhorn 무손실 이관** (AWX PostgreSQL: pg_dump → 새 PVC restore)
3. **ArgoCD 설치** → GitOps repo 연결 → App-of-Apps 부트스트랩
4. **kube-prometheus-stack + Loki(S3 백엔드)** 를 ArgoCD로 배포, `loki-override.yaml` `-f` 확인
5. **Trivy-Operator** 배포 (이미지 취약점 자동 스캔)
6. **OCI Object Storage 버킷** 생성 → Loki/Longhorn 백업 타깃 연결 (20GB 한도 내)
7. **과금 알람 이중 안전장치**: OCI 콘솔 **Budgets + Cost Alerts**를 $0.01 임계로 설정, Compartment Quota로 리소스 상한 강제

---

## 9. 무과금 상시 점검 체크리스트

- [ ] Ampere A1 총 OCPU ≤ 4, RAM ≤ 24GB
- [ ] Block Volume 총합 ≤ 200GB (`boot 47GB×2` 포함 계산)
- [ ] Object Storage ≤ 20GB, 월 API 요청 ≤ 50K
- [ ] OCI Monitoring/Logging 서비스 **미사용**(자체 Prometheus/Loki로 대체)
- [ ] Flexible LB 생성 안 함(ingress-nginx hostPort 사용)
- [ ] OCI **Budget $0.01 알람** + **Compartment Quota** 설정 완료
- [ ] Public IP는 Reserved(고정) 1~2개만 유지(유휴 Reserved IP 과금 주의)

---

## 10. 이 설계가 주는 것

| 축 | 결과 |
|----|------|
| **채용 경쟁력** | K8s + GitOps(ArgoCD) + IaC + 관측성 + DevSecOps = 2026 공고 정면 대응 스택 |
| **비용** | OCI Always Free 한도 내 **$0** (설계 단계에서 경계 차단) |
| **하이브리드 대응** | Longhorn Storage Tag로 OCI/홈랩 노드 모두 단일 스토리지 |
| **면접 스토리** | "WAN 동기복제 회피", "App-of-Apps", "무과금 경계 설계" 등 설명 가능한 의사결정 다수 |

---
*본 문서는 설계안입니다. 실제 적용 전 각 노드의 `providerID`, 블록볼륨 잔여 용량, OCI Budget 설정을 반드시 확인하세요.*
