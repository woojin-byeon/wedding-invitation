#!/usr/bin/env bash
# =====================================================================
# backup-homelab.sh  (FINAL)
#   홈랩 k3s(control-plane, repository 10.0.2.16)에서 uninstall '전에' 실행.
#   확정 환경:
#     - Helm: cert-manager v1.21.1 / duckdns v1.2.3 /
#             loki(loki-stack 2.10.3) / monitoring-stack(kube-prometheus-stack 88.3.0)
#     - AWX : kustomize 설치, 버전 24.6.1, name=awx (ns=awx)
#   결과: ~/homelab-backup-<ts>/ + tar.gz  →  반드시 홈랩 밖으로 복사!
# =====================================================================
set -uo pipefail
TS=$(date +%Y%m%d-%H%M%S)
BK="$HOME/homelab-backup-$TS"
mkdir -p "$BK"/{manifests,helm,secrets,db,gitea,info}
KC="kubectl"
echo "### Homelab backup -> $BK"

# 0) 스냅샷
$KC get nodes -o wide                         > "$BK/info/nodes.txt"    2>&1
$KC get all -A -o wide                         > "$BK/info/all.txt"      2>&1
$KC get pvc,pv,sc -A -o wide                    > "$BK/info/storage.txt"  2>&1
$KC get ingress -A -o wide                      > "$BK/info/ingress.txt"  2>&1
$KC get clusterissuer,issuer,certificate -A     > "$BK/info/certs.txt"    2>&1
$KC -n awx get deploy awx-operator-controller-manager \
   -o jsonpath='{.spec.template.spec.containers[*].image}' > "$BK/info/awx-operator-image.txt" 2>/dev/null

NS_LIST="awx monitoring demo-targets"

# 1) Helm values / manifest (재배포 근거)
if command -v helm >/dev/null 2>&1; then
  helm list -A -o yaml > "$BK/helm/releases.yaml" 2>&1 || true
  helm list -A 2>/dev/null | tail -n +2 | while read -r name ns rest; do
    [ -z "$name" ] && continue
    helm get values  "$name" -n "$ns" -o yaml > "$BK/helm/${ns}__${name}.values.yaml"   2>/dev/null || true
    helm get manifest "$name" -n "$ns"         > "$BK/helm/${ns}__${name}.manifest.yaml" 2>/dev/null || true
    echo "  helm saved: $ns/$name"
  done
fi

# 2) 네임스페이스별 매니페스트 export
API_NS=$($KC api-resources --verbs=list --namespaced -o name 2>/dev/null | sort -u)
for ns in $NS_LIST; do
  mkdir -p "$BK/manifests/$ns"
  for kind in $API_NS; do
    case "$kind" in events*|endpoints*|endpointslices*) continue;; esac
    out="$BK/manifests/$ns/${kind//\//_}.yaml"
    if $KC get "$kind" -n "$ns" -o yaml >"$out" 2>/dev/null; then
      grep -q 'items: \[\]' "$out" 2>/dev/null && rm -f "$out"
    else rm -f "$out"; fi
  done
  echo "  exported ns: $ns"
done

# 3) AWX CR
$KC -n awx get awx awx -o yaml > "$BK/manifests/awx-cr.yaml" 2>/dev/null || true

# 4) Secrets (★ secret_key 필수) — awx 전체 + 개별 강조
for ns in awx monitoring cert-manager; do
  $KC get secret -n "$ns" -o yaml > "$BK/secrets/${ns}-secrets.yaml" 2>/dev/null || true
done
for s in awx-secret-key awx-admin-password awx-postgres-configuration awx-app-credentials \
         awx-broadcast-websocket awx-tls; do
  $KC -n awx get secret "$s" -o yaml > "$BK/secrets/AWX__${s}.yaml" 2>/dev/null \
    && echo "  ★ secret saved: $s"
done
[ -s "$BK/secrets/AWX__awx-secret-key.yaml" ] \
  && echo "  ✅ awx-secret-key 확보(자격증명 복호화 핵심)" \
  || echo "  !! awx-secret-key 없음 - 반드시 수동 확인: kubectl -n awx get secret | grep secret-key"

# 5) AWX Postgres 논리 덤프 (가장 중요)
PGPOD="awx-postgres-15-0"
if $KC -n awx get pod "$PGPOD" >/dev/null 2>&1; then
  PGDB=$($KC -n awx get secret awx-postgres-configuration  -o jsonpath='{.data.database}' 2>/dev/null | base64 -d); PGDB=${PGDB:-awx}
  PGUSER=$($KC -n awx get secret awx-postgres-configuration -o jsonpath='{.data.username}' 2>/dev/null | base64 -d); PGUSER=${PGUSER:-awx}
  PGPASS=$($KC -n awx get secret awx-postgres-configuration -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
  echo "  pg: db=$PGDB user=$PGUSER"
  $KC -n awx exec -i "$PGPOD" -- bash -lc \
    "PGPASSWORD='$PGPASS' pg_dump -h 127.0.0.1 -U '$PGUSER' -d '$PGDB' --no-owner --clean --if-exists" \
    > "$BK/db/awx.sql" 2>"$BK/db/awx.dump.log"
  [ -s "$BK/db/awx.sql" ] && echo "  ✅ AWX DB 덤프: $(du -h "$BK/db/awx.sql"|cut -f1)" \
                          || echo "  !! 덤프 비었음 - db/awx.dump.log 확인"
fi

# 6) Gitea 데이터 (demo-targets, PVC 1Gi)
GPOD=$($KC -n demo-targets get pod -l app=gitea -o name 2>/dev/null | head -1)
if [ -n "$GPOD" ]; then
  $KC -n demo-targets exec "${GPOD#pod/}" -- tar czf - -C /data . > "$BK/gitea/gitea-data.tar.gz" 2>/dev/null \
    && echo "  ✅ gitea 데이터 확보"
else
  echo "  (gitea pod 0/0 상태일 수 있음 - 필요시 scale 후 재실행)"
fi

# 7) 압축
tar czf "$BK.tar.gz" -C "$(dirname "$BK")" "$(basename "$BK")"
echo
echo "### 완료: $BK.tar.gz"
echo "###  ★ 지금 즉시 홈랩 밖으로 복사:"
echo "###    scp $BK.tar.gz rocky@161.33.204.246:~/"
