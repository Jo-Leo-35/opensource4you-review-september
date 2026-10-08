#!/usr/bin/env bash
#
# preflight-check.sh — Kubernetes 動手前環境預檢（vendor-neutral）
# ============================================================
# 用途：在你對叢集做任何「會改變狀態」的動作（apply / delete / scale / label）之前，
#       先把「我用什麼工具、現在連到哪個叢集、預設在哪個 namespace、連得上嗎」全部攤開確認。
#
# 為什麼要做？
#   K8S 最容易出包的地方是：你以為在測試叢集 / 測試 namespace，其實 context 停在別處，
#   一個指令打下去就動到不該動的環境。這個腳本讓你動工前先「親眼確認」。
#
# 用法：bash preflight-check.sh
# 相依工具：kubectl（必要）。此腳本純唯讀，不會改動叢集。
#
# 註：此技能是 vendor-neutral 的 K8s 核心教學，不假設任何雲廠商 CLI（gcloud/aws/az）。
#     若你要做雲平台專屬部署（建 GKE 叢集、抓憑證、對外開放），請改用 gke-deploy 技能。
# ============================================================
set -uo pipefail   # 不用 set -e：預檢要盡量把問題「全部列出來」再一次性回報，而非遇錯即停

GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; YELLOW=$'\033[1;33m'; CYAN=$'\033[1;36m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
info(){ echo "${CYAN}[資訊]${RESET} $*"; }
ok(){   echo "${GREEN}[OK]${RESET}  $*"; }
warn(){ echo "${YELLOW}[警告]${RESET} $*"; }
fail(){ echo "${RED}[失敗]${RESET} $*"; }

echo "============================================================"
echo " Kubernetes 動手前環境預檢 (preflight-check)"
echo "============================================================"

HAS_ERROR=0

# ------------------------------------------------------------
# 步驟 1/4：檢查 kubectl 是否安裝
# ------------------------------------------------------------
info "步驟 1/4：檢查 kubectl 是否安裝..."
if command -v kubectl >/dev/null 2>&1; then
    ok "已找到 ${BOLD}kubectl${RESET}"
else
    fail "找不到 ${BOLD}kubectl${RESET}（尚未安裝或不在 PATH 中）"
    echo "      ${YELLOW}該怎麼修：${RESET}macOS 用 'brew install kubectl'；其他平台見 https://kubernetes.io/docs/tasks/tools/"
    echo
    fail "沒有 kubectl 無法繼續，請先安裝後重跑。"
    exit 1
fi
echo

# ------------------------------------------------------------
# 步驟 2/4：顯示目前 kubectl 連到哪個叢集，並請你確認
# ------------------------------------------------------------
info "步驟 2/4：確認 kubectl 目前連到的叢集與 namespace..."
KUBE_CONTEXT="$(kubectl config current-context 2>/dev/null || true)"

if [[ -z "$KUBE_CONTEXT" ]]; then
    fail "kubectl 目前沒有設定任何 context（還沒連上任何叢集）。"
    echo "      ${YELLOW}該怎麼修：${RESET}"
    echo "        - 本機練習：啟動 minikube（'minikube start'）或 kind（'kind create cluster'）。"
    echo "        - 既有叢集：把 kubeconfig 放到 ~/.kube/config，或用你叢集供應方的方式抓憑證。"
    HAS_ERROR=1
else
    KUBE_CLUSTER="$(kubectl config view --minify -o 'jsonpath={.clusters[0].name}' 2>/dev/null || true)"
    KUBE_SERVER="$(kubectl config view --minify -o 'jsonpath={.clusters[0].cluster.server}' 2>/dev/null || true)"
    KUBE_NS="$(kubectl config view --minify -o 'jsonpath={..namespace}' 2>/dev/null || true)"
    [[ -z "$KUBE_NS" ]] && KUBE_NS="default（未指定，預設 default）"

    echo
    echo "${YELLOW}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo "${YELLOW}║${RESET}  ${BOLD}⚠️  接下來的操作會打到下面這個叢集 / namespace！${RESET}"
    echo "${YELLOW}╠══════════════════════════════════════════════════════════╣${RESET}"
    echo "${YELLOW}║${RESET}  Context   : ${CYAN}${BOLD}${KUBE_CONTEXT}${RESET}"
    echo "${YELLOW}║${RESET}  Cluster   : ${CYAN}${BOLD}${KUBE_CLUSTER}${RESET}"
    echo "${YELLOW}║${RESET}  位址       : ${KUBE_SERVER}"
    echo "${YELLOW}║${RESET}  Namespace : ${CYAN}${BOLD}${KUBE_NS}${RESET}"
    echo "${YELLOW}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo

    read -r -p "${BOLD}以上叢集 / namespace 正確嗎？確定要對它動手嗎？(y/N) ${RESET}" CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        warn "你選擇了不繼續。請先切換到正確的環境再重跑本腳本。"
        echo "      ${YELLOW}切換方式：${RESET}"
        echo "        1) 看有哪些叢集     ：kubectl config get-contexts"
        echo "        2) 切換 context     ：kubectl config use-context <CONTEXT>"
        echo "        3) 設定預設 namespace：kubectl config set-context --current --namespace=<NS>"
        exit 1
    fi
    ok "已確認環境：context=${BOLD}${KUBE_CONTEXT}${RESET}，namespace=${BOLD}${KUBE_NS}${RESET}"
fi
echo

# ------------------------------------------------------------
# 步驟 3/4：實際驗證「真的連得上」叢集（純唯讀）
# ------------------------------------------------------------
info "步驟 3/4：驗證與叢集的連線（唯讀查詢，不會改動任何東西）..."
if kubectl cluster-info >/dev/null 2>&1; then
    ok "kubectl cluster-info 成功：控制平面(control plane)有回應。"
else
    fail "kubectl cluster-info 失敗：連不到叢集控制中樞。"
    echo "      ${YELLOW}可能原因：${RESET}憑證過期、叢集未啟動（minikube/kind 沒開）、或網路/VPN 不通。"
    HAS_ERROR=1
fi

if kubectl get nodes >/dev/null 2>&1; then
    NODE_COUNT="$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    ok "kubectl get nodes 成功：叢集中目前有 ${BOLD}${NODE_COUNT}${RESET} 個節點。"
else
    fail "kubectl get nodes 失敗：可能沒有權限，或連線有問題。"
    echo "      ${YELLOW}該怎麼修：${RESET}確認帳號在此叢集有足夠 RBAC 權限；或重新設定 kubeconfig。"
    HAS_ERROR=1
fi
echo

# ------------------------------------------------------------
# 步驟 4/4：總結
# ------------------------------------------------------------
info "步驟 4/4：彙整檢查結果..."
if [[ "$HAS_ERROR" -ne 0 ]]; then
    echo
    fail "預檢未通過：請先依上面標示的提示處理，再重新執行本腳本。"
    exit 1
fi

echo
echo "${GREEN}============================================================${RESET}"
echo "${GREEN}${BOLD} ✅ 全部檢查通過！環境已就緒。${RESET}"
echo "${GREEN}    Context   : ${KUBE_CONTEXT:-（未設定）}${RESET}"
echo "${GREEN}    Namespace : ${KUBE_NS:-default}${RESET}"
echo "${GREEN}============================================================${RESET}"
echo "${CYAN}提醒：套用前先 'kubectl apply -f x.yaml --dry-run=client -o yaml' 預覽，改動一次只改一個變因。${RESET}"
exit 0
