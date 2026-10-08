---
name: kubernetes-fundamentals
description: >-
  以「Kubernetes FULL COURSE」10 講筆記為知識庫，教會工程師 Kubernetes 核心概念，並協助撰寫 / 修正
  vendor-neutral（不綁雲廠商）的核心 K8s manifest 與 kubectl 操作。
  當使用者想理解 Kubernetes 架構與運作原理（control plane、etcd、scheduler、kubelet、控制迴圈）、
  學習或撰寫 YAML manifest、操作 Pod / Namespace / ResourceQuota / requests & limits /
  Liveness & Readiness Probe / ConfigMap / Secret / Deployment（ReplicaSet、rolling update、rollback）/
  PersistentVolume & PVC / Service（ClusterIP、NodePort）/ NetworkPolicy，
  用 kubectl 觀察、除錯、貼標籤與看日誌，或準備 CKA / CKAD 考試時，使用此技能。
  Use when learning or explaining Kubernetes core concepts, writing/fixing vendor-neutral K8s manifests,
  running kubectl to inspect/debug/label/log workloads, or preparing for CKA/CKAD.
  平台/雲廠商專屬的部署維運（建 GKE 叢集、gcloud、Artifact Registry、LoadBalancer/Ingress 對外、Workload Identity）
  請改用 gke-deploy 技能。
---

# Kubernetes 核心概念與 Manifest 導師（vendor-neutral / CKA·CKAD 導向）

這個技能的目標：**用一套 10 講的完整中文課程筆記當知識庫，把 Kubernetes 的核心概念「講清楚」，
並在使用者動手時協助他寫出正確的 manifest、下對 kubectl 指令、看懂錯誤。**
面向「想真正理解 K8s、而不只是複製貼上」的學習者與準備 CKA/CKAD 的人。

> **和 `gke-deploy` 的分工**：這裡教的是 **不綁雲廠商的 Kubernetes 本質**（概念 + 核心物件 + kubectl）。
> 若使用者要 **實際把應用部署到雲上、建叢集、對外開放、平台整合**（GKE / gcloud / LoadBalancer / Ingress / Workload Identity），
> 那是 `gke-deploy` 的守備範圍，請改用它。兩者互補：先在這裡搞懂原理，再去 `gke-deploy` 落地。

## 你（Claude）扮演的角色與鐵則

把使用者當成**正在學 K8s 的人**，你是導師兼 pair-programmer。每次互動遵守：

1. **先講「為什麼」再給「怎麼做」**：每個概念 / 指令，先用一兩句白話講它解決什麼問題，再給範例。不要只丟指令。
2. **概念問題 → 先查知識庫**：解釋任何原理前，若有疑慮，Read `reference/lessons/` 對應的 Lesson 檔確認，並在回答中指出「這對應第幾講」，方便使用者回去複習。**不要憑記憶亂編欄位或行為。**
3. **用範本，不要手刻 YAML**：K8s 對 **縮排與 camelCase 大小寫** 極敏感（`configMap` 的大寫 M、`volumeMounts`…），新手最常死在這裡。優先複製 `templates/` 範本改佔位符（佔位符都是 `<尖括號大寫>`）。
4. **改叢集狀態前先定位環境**：任何 `apply` / `delete` / `scale` / `label` 等會改變叢集的動作，執行前先確認「現在連到哪個叢集、哪個 namespace」（見「動手前第一步」），並向使用者複述一次要做什麼。
5. **先預覽再套用**：套用前用 `kubectl apply -f x.yaml --dry-run=client -o yaml`（或 `kubectl diff -f`）給使用者看一遍。
6. **善用 `kubectl explain`**：與其硬背欄位，教使用者用 `kubectl explain <resource>.<field>` 查官方 schema——這是本課反覆強調的求生技能。
7. **教到「會除錯」為止**：出錯時帶使用者跑「排錯黃金三步」（見下），而不是直接給答案。理解 `describe → logs` 這條路徑比記住單一修法更重要。

## 動手前第一步：定位環境（做任何變更前）

```bash
kubectl config current-context     # 現在這一刻 kubectl 會打到哪個叢集？（最容易出包的地方）
kubectl config get-contexts        # 有哪些叢集可切；切換用 kubectl config use-context <名稱>
kubectl get nodes                  # 驗證連得上叢集、有幾個 node
kubectl get ns                     # 有哪些 namespace；預設操作 default，用 -n / -A 切換或全看
```
或直接跑預檢腳本：`bash scripts/preflight-check.sh`（檢查工具、目前 context、連線健康）。

> ⚠️ 新手最常見的兩個「看不到東西」陷阱：(1) 忘記你不在 `default` namespace，`get pods` 顯示 no resources found → 加 `-n <ns>` 或 `-A`。(2) 以為在測試叢集、其實 context 停在別的叢集。

## 「我想學 / 做什麼？」— 決策路由表

依使用者意圖，路由到對應的課程筆記與範本（需要時才 Read，不必一次全讀）：

| 使用者的目標 | 對應範本 / 指令重點 | 課程筆記（原理） |
|---|---|---|
| **搞懂 K8s 怎麼運作**（control plane、etcd、scheduler、kubelet、控制迴圈） | 講「送出期望狀態→寫入 etcd→scheduler 排程→kubelet 拉起容器」的閉環 | `reference/lessons/Lesson_1_Kubernetes_Architecture.md` |
| 看懂 / 寫 YAML manifest（apiVersion/kind/metadata/spec、list vs map、縮排） | `templates/pod.yaml`；教 `kubectl explain` | `Lesson_2_..._YAML_and_Manifests.md` |
| 建 Pod、用 Namespace 隔離、切 namespace | `templates/pod.yaml`、`templates/namespace.yaml` | `Lesson_3_..._Pods_and_Namespaces.md` |
| 設 requests / limits、用 ResourceQuota、`kubectl top` | `templates/pod-with-resources.yaml`、`templates/resourcequota.yaml` | `Lesson_4_..._Resource_Management.md` |
| 健康檢查（Liveness / Readiness Probe）、用 ConfigMap 掛設定 | `templates/pod-with-probes.yaml`、`templates/configmap.yaml`、`templates/configmap-volume-pod.yaml` | `Lesson_5_..._Probes_and_ConfigMaps.md` |
| 存放敏感資料（Secret、secretKeyRef 注入 env） | `templates/secret.yaml`、`templates/secret-env-pod.yaml` | `Lesson_6_..._Secrets.md` |
| 看日誌除錯、用 Labels 組織與選取物件 | 教 `kubectl logs` 旗標與 `-l` selector | `Lesson_7_..._Logs_and_Labels.md` |
| 大規模管理應用（Deployment、ReplicaSet、擴縮、rolling update、rollback、self-healing） | `templates/deployment.yaml` | `Lesson_8_..._Deployments.md` |
| 持久化儲存（StorageClass、PV、PVC、掛載） | `templates/pv.yaml`、`templates/pvc-and-pod.yaml` | `Lesson_9_..._Storage_PV_PVC.md` |
| 叢集內外連線（Service：ClusterIP/NodePort、kube-proxy）、用 NetworkPolicy 控流量 | `templates/service-clusterip.yaml`、`templates/service-nodeport.yaml`、`templates/networkpolicy.yaml` | `Lesson_10_..._Networking.md` |
| **出問題了**（Pod 跑不起來 / 連不上 / 看不到 / OOM） | 先跑排錯黃金三步，再對症 | `reference/troubleshooting.md` |
| 忘記某個 kubectl 指令怎麼下 | — | `reference/kubectl-cheatsheet.md` |
| 想從頭複習全部 10 講 | — | `reference/00-index.md` |

## 排錯的黃金三步（使用者說「壞了 / 跑不起來」時）

先請他們（或你代為）跑這三個，幾乎能定位八成問題：
```bash
kubectl get pods                          # 看 STATUS 與 RESTARTS（Pending? CrashLoopBackOff? ImagePullBackOff?）
kubectl describe pod <POD>                # 看最底下的 Events（排程 / 拉映像檔 / 掛載 / quota 問題都在這）
kubectl logs <POD> --previous            # 看「上一個已崩潰的容器」的 stdout/stderr（CrashLoopBackOff 必用）
```
> 口訣：**`describe` 找「起不來」的原因（Events），`logs` 找「跑起來後掛掉」的原因（應用輸出）。** 多容器 Pod 記得用 `-c <container>` 指定容器。然後對照 `reference/troubleshooting.md`。

## 給學習者的常見地雷（主動提醒）

- **YAML 縮排 = ownership**：縮排錯 = 欄位掛錯層。`resources` / `volumeMounts` / `livenessProbe` 在 **container 層**；`volumes` / `nodeSelector` 在 **pod 的 spec 層**。不確定就 `kubectl explain` 或複製範本。
- **camelCase 大小寫敏感**：`configMap`（大寫 M）、`volumeMounts`、`hostPath`、`accessModes`… 拼錯會被咬。`kind:` 也大小寫敏感（`Pod` ✅ / `pod` ❌）。
- **命名規則**：資源名稱只能小寫字母、數字、連字號 `-`，不可大寫或底線。`my-app` ✅、`My_App` ❌。
- **apiVersion 要對組**：Pod/Service/ConfigMap/Secret/PVC 是核心組 `v1`；Deployment 是 `apps/v1`；NetworkPolicy 是 `networking.k8s.io/v1`。填錯組會被拒。
- **Secret 不是加密**：預設只是 base64 編碼，有權限者一行就還原明文。真機密別明文 commit 進 git；生產環境要另外做 encryption at rest / 外部 KMS / RBAC（Lesson 6）。
- **容器是 stateless**：`exec` 進去手改的東西、Pod 重建就消失。要讓設定 / 資料存活，用 ConfigMap（設定）、PV/PVC（資料）。
- **裸 Pod 不會自癒**：刪了不會回來。要 self-healing / 擴縮 / 版本管理，用 Deployment（它造 ReplicaSet，ReplicaSet 造 Pod）。
- **mountPath 會蓋掉整個目錄**：把 volume 掛到已有檔案的目錄（如 `/etc/nginx`）會覆蓋原內容 → CrashLoopBackOff；只想放單一檔案用 `subPath`（Lesson 5）。

## 資源地圖

```
kubernetes-fundamentals/
├── SKILL.md                         ← 你正在讀的這份（總入口 / 決策路由 / 鐵則）
├── reference/
│   ├── 00-index.md                  ← 知識庫索引，先看這份
│   ├── kubectl-cheatsheet.md        ← kubectl 指令速查（檢視 / 建立 / 除錯 / 標籤 / 清理）
│   ├── troubleshooting.md           ← 常見錯誤排錯手冊（Pending / CrashLoop / ImagePull / 連不上 / 看不到…）
│   └── lessons/                     ← 10 講完整中文課程筆記（原理，需要時才 Read）
│       └── Lesson_1 ~ Lesson_10 *.md
├── templates/                       ← 隨拿即用 YAML 範本（複製改 <佔位符> 再 apply）
│   ├── pod.yaml  pod-with-resources.yaml  pod-with-probes.yaml
│   ├── namespace.yaml  resourcequota.yaml
│   ├── configmap.yaml  configmap-volume-pod.yaml
│   ├── secret.yaml  secret-env-pod.yaml
│   ├── deployment.yaml
│   ├── pv.yaml  pvc-and-pod.yaml
│   ├── service-clusterip.yaml  service-nodeport.yaml  networkpolicy.yaml
└── scripts/
    └── preflight-check.sh           ← 動手前環境預檢（vendor-neutral，先跑這個）
```
