# OCI Object Storage(S3) 연동 런북 — Loki & AWX

> **목표**: OCI Object Storage의 **S3 호환 API**를 백엔드로 사용하여
> - **Loki** 로그를 오브젝트 스토리지에 영속 저장 (노드/PVC 종속 제거)
> - **AWX** 백업을 오브젝트 스토리지로 오프사이트 보관
>
> 이를 통해 **Ceph RGW와 동일한 "오브젝트 스토리지 백엔드" 아키텍처**를
> **과금·안정성 리스크 0**으로 도입한다.

---

## 0. 왜 이 접근인가 (개념)

Ceph RGW · AWS S3 · MinIO · OCI Object Storage는 전부 **S3 호환 API를 노출하는 오브젝트 스토리지**다.
애플리케이션 입장에서는 넷 다 동일한 인터페이스로 접근한다:

```
S3 endpoint + Access Key + Secret Key + Bucket
```

따라서 **여기서 배우는 패턴(S3 백엔드 연동)은 Ceph RGW · MinIO · AWS S3에 그대로 이식**된다.
이것이 이 접근의 핵심 학습 가치다.

### 왜 클러스터 내부 분산 스토리지(Ceph/Longhorn) 대신 이걸 쓰는가

| 제약 | 내용 |
|---|---|
| **과금 위험** | OCI Always Free 블록 스토리지는 **부팅볼륨 포함 총 200GB**. A1 2노드 부팅볼륨(~100GB)을 빼면 여유 ~100GB뿐 → Block Volume 추가 시 초과분 과금 위험 |
| **repository 불안정** | repository 노드는 노트북(x86 4core/8GB)이라 **수시로 네트워크 단절**. 분산 스토리지의 MON/replica 멤버로 쓰면 노드 이탈 시 스토리지 전체 다운 |
| **자원 부족** | 안정 노드는 OCI A1 2개(각 1core)뿐 → Ceph(최소 3노드+raw disk)·Longhorn 모두 빠듯 |

➡️ **결론**: 스토리지를 클러스터 밖 OCI Object Storage로 빼면 위 세 리스크가 모두 사라진다.
**오브젝트 스토리지 20GB는 블록 볼륨 200GB와 완전히 별개**라 과금 걱정이 없다.

### Ceph vs 이 접근 — 기술적으로 같은가?

- **Ceph RGW**: Ceph 클러스터 위에 S3 호환 게이트웨이(RADOS Gateway)를 얹은 것
- **OCI Object Storage(S3 API)**: OCI가 관리형으로 제공하는 S3 호환 오브젝트 스토리지
- **애플리케이션 연동 관점에서 두 개는 동일한 개념** — endpoint/access key/secret key/bucket으로 접근
- 차이는 "누가 스토리지 인프라를 운영하느냐"뿐. 개념·연동 코드·설정은 이식 가능

---

## 1. OCI 준비 (콘솔 + CLI)

### 1-1. 환경 값 (본 환경 실제 값)

| 항목 | 값 |
|---|---|
| Region | `ap-tokyo-1` (Japan East - Tokyo) |
| Availability Domain | `jUZi:AP-TOKYO-1-AD-1` |
| Object Storage Namespace | `nr2dcwqo61cs` |
| **S3 Endpoint** | `https://nr2dcwqo61cs.compat.objectstorage.ap-tokyo-1.oci.customer-oci.com` |
| Access Key | `<콘솔 Customer secret keys 테이블에서 복사>` |
| Secret Key | `<생성 시 1회만 표시 — 안전 보관>` |

> **Endpoint 조합 규칙**:
> `https://{namespace}.compat.objectstorage.{region}.oci.customer-oci.com`

### 1-2. 버킷 2개 생성

콘솔 좌상단 햄버거 메뉴 → **Storage → Buckets → Create Bucket**

- `loki-chunks`  — Loki 로그 청크/인덱스
- `awx-backups`  — AWX 백업 아카이브

CLI로도 가능:

```bash
oci os bucket create --name loki-chunks --compartment-id <compartment-ocid>
oci os bucket create --name awx-backups  --compartment-id <compartment-ocid>
```

### 1-3. Namespace 확인 (이미 완료)

```bash
oci os ns get
# {
#   "data": "nr2dcwqo61cs"
# }
```

### 1-4. Customer Secret Key 발급 (S3 인증용)

콘솔 우상단 프로필 → **My profile** → 상단 탭 **`Tokens and keys`**
→ **Customer secret keys** 섹션 → **Generate secret key**

- 이름 예: `s3-loki-awx`
- ⚠️ **Secret Key는 생성 순간 딱 한 번만 표시** → 즉시 복사·안전 보관 (분실 시 재발급만 가능)
- **Access Key**는 테이블에 영구 표시되어 언제든 복사 가능
- OCI S3 호환 API는 **오직 Customer Secret Key만** 인증에 사용 (instance principal 불가)

> 🔐 **보안**: Secret Key를 채팅/로그/git 등에 노출했다면 **즉시 폐기(delete) 후 재발급**할 것.

### 1-5. IAM 정책 (최소 권한)

콘솔 → **Identity → Policies** 에서 (또는 도메인 정책):

```
Allow group <your-group> to manage object-family in compartment <compartment> where target.bucket.name='loki-chunks'
Allow group <your-group> to manage object-family in compartment <compartment> where target.bucket.name='awx-backups'
```

---

## 2. OCI S3 API의 필수 특이점 (반드시 기억)

표준 S3와 거의 같지만 **두 가지 필수 조정**이 있다. 이걸 놓치면 연동이 실패한다.

1. **Path-style 강제**
   OCI는 `bucket.endpoint/key`(virtual-hosted)가 아니라
   **`endpoint/bucket/key`(path-style)** 만 지원
   → 클라이언트에 **`s3forcepathstyle: true`** (또는 동등 옵션) 필수

2. **Endpoint 형식 고정**
   `https://{namespace}.compat.objectstorage.{region}.oci.customer-oci.com`

3. **인증 = Customer Secret Key (AWS SigV4)**
   Access Key / Secret Key 정적 페어를 SigV4로 서명

4. **Chunked encoding 주의**
   일부 SDK가 기본으로 붙이는 trailing checksum(aws-chunked)을 OCI가 거부(`501 NotImplemented`)할 수 있음
   → 대부분의 클라이언트는 path-style 지정 시 자동 처리됨

---

## 3. Loki → S3 백엔드 전환

> ⚠️ 현재 사용 중인 `loki-stack` 차트는 **deprecated**이며, single-binary Loki는
> 구식 `schema_config`/`storage_config` 방식으로 S3를 설정한다. 아래는 **현재 차트 유지 기준**의 최소 변경안이다.

### 3-1. S3 인증정보를 Secret으로 (평문 회피 권장)

```bash
kubectl create secret generic loki-s3-creds -n monitoring \
  --from-literal=AWS_ACCESS_KEY_ID='<Access_Key>' \
  --from-literal=AWS_SECRET_ACCESS_KEY='<Secret_Key>'
```

### 3-2. loki-override.yaml (S3 storage 설정)

기존 `loki-override.yaml`의 `loki:` 블록에 아래 config를 반영한다.
(이미 있는 `nodeSelector` 등 다른 키는 유지)

```yaml
loki:
  config:
    schema_config:
      configs:
        - from: 2026-09-01
          store: boltdb-shipper
          object_store: s3
          schema: v13
          index:
            prefix: loki_index_
            period: 24h
    storage_config:
      boltdb_shipper:
        active_index_directory: /data/loki/index
        cache_location: /data/loki/index_cache
      aws:
        # s3://<ACCESS_KEY>:<SECRET_KEY>@<REGION>/<BUCKET>
        s3: s3://<Access_Key>:<Secret_Key>@ap-tokyo-1/loki-chunks
        endpoints: https://nr2dcwqo61cs.compat.objectstorage.ap-tokyo-1.oci.customer-oci.com
        region: ap-tokyo-1
        s3forcepathstyle: true          # ★ OCI 필수 (path-style)
    compactor:
      working_directory: /data/loki/compactor
      shared_store: s3

# (참고) 기존에 넣어둔 다른 값들은 그대로 유지
# nodeSelector: {}
# grafana:
#   enabled: false
#   sidecar:
#     datasources:
#       enabled: false
```

> **주의**: 위처럼 `s3://key:secret@...` 형태로 자격증명을 인라인하면 values에 평문이 남는다.
> 보안이 중요하면 자격증명을 환경변수/Secret으로 주입하는 방식(차트 버전별 지원 여부 확인)을 사용한다.

### 3-3. 적용 & 검증

```bash
# reset-values로 이전 값 잔재 제거 후 적용 (nodeSelector 함정 회피)
helm get values loki -n monitoring -o yaml > loki-current-values.yaml
# → loki-current-values.yaml 에 위 config 병합 후:
helm upgrade loki grafana/loki-stack -n monitoring --reset-values -f loki-current-values.yaml

# 1) Loki 로그에서 S3 연동 에러 없는지
kubectl logs -n monitoring loki-0 --tail=50 | grep -iE "s3|store|error"

# 2) 실제로 버킷에 객체가 올라가는지 (몇 분 후)
oci os object list -bn loki-chunks
```

버킷에 인덱스/청크 객체가 생기면 성공.
이제 **loki-0가 죽거나 다른 노드로 옮겨가도 로그가 S3에 안전** — PVC/노드 종속 완전 해소.

### 3-4. Loki S3 연동 흔한 오류 3가지

| 증상 | 원인 | 해결 |
|---|---|---|
| `SignatureDoesNotMatch` / 403 | Access/Secret Key 오타, 정책 권한 부족 | 키 재확인, IAM 정책의 bucket 이름 확인 |
| `501 NotImplemented (aws-chunked)` | path-style 미적용 | `s3forcepathstyle: true` 확인 |
| 연결 타임아웃 / `no such host` | endpoint 오타 (namespace/region) | `https://nr2dcwqo61cs.compat.objectstorage.ap-tokyo-1.oci.customer-oci.com` 정확히 |

---

## 4. AWX 백업 → 오브젝트 스토리지

AWX DB(PostgreSQL)는 실시간 S3 백엔드를 쓰지 않는다(블록 스토리지 필요).
AWX에서 오브젝트 스토리지의 올바른 활용은 **백업 아카이브를 S3로 오프사이트 보관**하는 것이다.

### 백업 대상 (반드시)

| 대상 | 내용 | 중요도 |
|---|---|---|
| PostgreSQL DB | job/template/inventory/history 등 전체 | ✅ 필수 |
| **SECRET_KEY** | 크리덴셜 암호화 키. 분실 시 암호화된 값 **복구 불가** | ✅✅ 최중요 |
| Kubernetes secrets | admin password, DB 연결정보 | ✅ 필수 |
| AWX CR | operator 배포 정의 | ✅ 필수 |
| projects dir | 수동 프로젝트 파일 (SCM에 있으면 불필요) | 선택 |

### 4-1. AWXBackup CR로 PVC에 백업 생성

```yaml
# awx-backup.yml
apiVersion: awx.ansible.com/v1beta1
kind: AWXBackup
metadata:
  name: awx-backup-20260831
  namespace: awx
spec:
  deployment_name: awx
  backup_pvc: awx-backup-pvc
```

```bash
# 백업 PVC 준비 (없다면)
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: awx-backup-pvc
  namespace: awx
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-path
EOF

kubectl apply -f awx-backup.yml
kubectl get awxbackup -n awx -w   # 완료까지 모니터링
```

### 4-2. 백업 tar를 OCI Object Storage(S3)로 업로드

AWS CLI를 OCI S3 호환 endpoint로 사용:

```bash
aws configure set aws_access_key_id <Access_Key>
aws configure set aws_secret_access_key <Secret_Key>

aws s3 cp /path/awx-backup-20260831.tar.gz \
  s3://awx-backups/ \
  --endpoint-url https://nr2dcwqo61cs.compat.objectstorage.ap-tokyo-1.oci.customer-oci.com \
  --region ap-tokyo-1
```

> AWS CLI는 OCI S3 호환 API에서 **SigV4 + path-style**로 동작한다.

### 4-3. (선택) 자동 백업 CronJob

```yaml
# awx-backup-to-s3-cronjob.yml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: awx-backup-to-s3
  namespace: awx
spec:
  schedule: "0 2 * * *"     # 매일 02:00
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: awx-operator-controller-manager
          restartPolicy: OnFailure
          containers:
            - name: backup-trigger
              image: amazon/aws-cli:latest
              env:
                - name: AWS_ACCESS_KEY_ID
                  valueFrom: { secretKeyRef: { name: loki-s3-creds, key: AWS_ACCESS_KEY_ID } }
                - name: AWS_SECRET_ACCESS_KEY
                  valueFrom: { secretKeyRef: { name: loki-s3-creds, key: AWS_SECRET_ACCESS_KEY } }
              command:
                - /bin/sh
                - -c
                - |
                  # (사전에 AWXBackup으로 생성된 tar를 마운트/복사하는 로직 추가 필요)
                  aws s3 cp /backups/ s3://awx-backups/ --recursive \
                    --endpoint-url https://nr2dcwqo61cs.compat.objectstorage.ap-tokyo-1.oci.customer-oci.com \
                    --region ap-tokyo-1
```

> 위 CronJob은 뼈대다. 실제로는 AWXBackup PVC를 마운트하거나, backup 생성→업로드를 한 파이프라인으로 묶어야 한다.

---

## 5. 결과 정리

| 구성요소 | Before | After | 효과 |
|---|---|---|---|
| **Loki 로그** | emptyDir/PVC (노드 종속, 재기동 시 소실) | **OCI S3 (`loki-chunks`)** | 노드 무관·영속·repository 꺼져도 안전 |
| **AWX 백업** | 없음/PVC only | **OCI S3 (`awx-backups`)** | 클러스터 밖 보관, DR 가능 |
| **배우는 개념** | 로컬 스토리지 | **S3 오브젝트 백엔드** (Ceph RGW·MinIO 이식 가능) | 채용시장 핵심 스킬 |
| **비용/안정성** | — | 20GB 무료 · 과금 0 · 노드 리스크 0 | 리스크 없음 |

---

## 6. 체크리스트

- [ ] 버킷 `loki-chunks`, `awx-backups` 생성
- [ ] Customer Secret Key 발급 (Access Key/Secret Key 확보)
- [ ] IAM 정책으로 버킷 write 권한 부여
- [ ] Loki `s3forcepathstyle: true` + endpoint 정확히 반영
- [ ] `helm upgrade --reset-values` 적용 후 `oci os object list -bn loki-chunks`로 객체 확인
- [ ] AWXBackup CR 생성 → tar를 `awx-backups` 버킷 업로드
- [ ] **노출된 Secret Key 폐기 후 재발급** (보안)

---

## 부록: 환경 값 빠른 참조

```text
Region            : ap-tokyo-1
AD                : jUZi:AP-TOKYO-1-AD-1
Namespace         : nr2dcwqo61cs
S3 Endpoint       : https://nr2dcwqo61cs.compat.objectstorage.ap-tokyo-1.oci.customer-oci.com
Loki bucket       : loki-chunks
AWX backup bucket : awx-backups
Access Key        : <콘솔 Customer secret keys 테이블>
Secret Key        : <생성 시 1회 표시 — 안전 보관 / 노출 시 재발급>
```
