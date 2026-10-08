# Kubernetes 核心概念導師 — 知識庫索引

這個資料夾是 `kubernetes-fundamentals` 技能的知識庫。內容分兩類：
**操作型**（kubectl 速查、排錯手冊）與 **原理型**（10 講完整課程筆記）。
需要時再 Read 對應檔案，不必一次全讀。

## 🚀 操作型文件（日常會用到）

| 檔案 | 什麼時候看 |
|---|---|
| [kubectl-cheatsheet.md](kubectl-cheatsheet.md) | 忘記某個 `kubectl` 指令怎麼下（檢視 / 建立 / 更新 / 除錯 / 標籤 / 清理）。 |
| [troubleshooting.md](troubleshooting.md) | 出問題時。Pod Pending / ImagePullBackOff / CrashLoopBackOff / OOMKilled、看不到資源、連不上服務、被 NetworkPolicy/Quota 擋。 |

## 📚 原理型文件：10 講課程筆記（想搞懂背後為什麼）

對應「Kubernetes FULL COURSE」逐講的繁體中文高密度筆記。建議照順序讀，每一講都自帶
一句話總覽、知識地圖、核心重點、術語表、詳細筆記、實作範例、常見誤解、Q&A、跨領域連結。

| # | 檔案 | 主題 | 涵蓋重點 |
|---|---|---|---|
| 1 | [lessons/Lesson_1_Kubernetes_Architecture.md](lessons/Lesson_1_Kubernetes_Architecture.md) | 叢集架構與運作原理 | 為何用 K8s、Pod/Node/Cluster、kubectl/kubeconfig、kube-apiserver、etcd、scheduler、controller-manager、kubelet、container runtime；`kubectl create pod` 的端到端控制流；架構＝除錯能力 |
| 2 | [lessons/Lesson_2_Kubernetes_YAML_and_Manifests.md](lessons/Lesson_2_Kubernetes_YAML_and_Manifests.md) | YAML 與 Manifest 入門 | 宣告式「訂單」比喻、YAML list/map/純量、縮排＝ownership、四大頂層欄位 apiVersion/kind/metadata/spec、containers/ports 是 list、`kubectl explain`、image 名稱是最大地雷 |
| 3 | [lessons/Lesson_3_Kubernetes_Pods_and_Namespaces.md](lessons/Lesson_3_Kubernetes_Pods_and_Namespaces.md) | Pods 與 Namespaces | `kubectl get/describe/delete`、READY 與 RESTARTS 欄位、`apply` vs `create`、Events 除錯、namespace 隔離與 `-n`/`-A`、多容器 Pod、命令式 vs 宣告式建 namespace |
| 4 | [lessons/Lesson_4_Kubernetes_Resource_Management.md](lessons/Lesson_4_Kubernetes_Resource_Management.md) | 資源管理：Requests 與 Limits | apiVersion＝API 版本、metrics-server 與 `kubectl top`、requests（保證下限）vs limits（硬上限）、millicore CPU、`limits ≥ requests` 鐵律、ResourceQuota namespace 配額 |
| 5 | [lessons/Lesson_5_Kubernetes_Probes_and_ConfigMaps.md](lessons/Lesson_5_Kubernetes_Probes_and_ConfigMaps.md) | 健康探針與設定解耦 | Liveness（失敗殺重啟）vs Readiness（失敗切流量）、四個時間參數、httpGet 探測、ConfigMap→Volume→Pod→Container 掛載鏈、`exec`/`cp` 手改的無常、mountPath 覆蓋陷阱與 subPath |
| 6 | [lessons/Lesson_6_Kubernetes_Secrets.md](lessons/Lesson_6_Kubernetes_Secrets.md) | Secrets 安全存放敏感資料 | Secret 預設只 base64 不加密、type（Opaque/basic-auth/…）、宣告式 stringData vs data、命令式 `--from-literal`、secretKeyRef 注入 env、明文密碼反例、encryption at rest / RBAC 延伸 |
| 7 | [lessons/Lesson_7_Kubernetes_Logs_and_Labels.md](lessons/Lesson_7_Kubernetes_Logs_and_Labels.md) | 日誌與標籤：除錯與組織 | `kubectl logs` 旗標（`-c`/`--all-containers`/`-f`/`--since`/`--previous`）、日誌的無常性與 `/var/log/pods`、labels 是 key-value metadata、`--show-labels`/`-L`、`-l` selector 批次選取 |
| 8 | [lessons/Lesson_8_Kubernetes_Deployments.md](lessons/Lesson_8_Kubernetes_Deployments.md) | Deployments：大規模管應用 | 裸 Pod 不自癒、replicas 與 `kubectl scale`、self-healing、兩層 metadata/spec、selector.matchLabels 認領 Pod、template、Deployment→ReplicaSet→Pod 責任鏈、rolling update 與 rollout undo |
| 9 | [lessons/Lesson_9_Kubernetes_Storage_PV_PVC.md](lessons/Lesson_9_Kubernetes_Storage_PV_PVC.md) | 持久化儲存 PV / PVC | 容器為何存不了資料、StorageClass→PV→PVC→Pod 四段路徑、accessModes（ReadWriteOnce）、hostPath、PVC 靠相同 storageClassName 綁定、掛載兩步驟、nodeSelector、驗證持久性 |
| 10 | [lessons/Lesson_10_Kubernetes_Networking.md](lessons/Lesson_10_Kubernetes_Networking.md) | 網路：Services 與 NetworkPolicy | Pod IP 是移動目標、Service 追蹤 endpoints、服務發現、port vs targetPort、kube-proxy/iptables round-robin、三種 Service 型別（ClusterIP/NodePort/LoadBalancer）、NetworkPolicy default-deny 與白名單、OR/AND 陷阱 |

## 🗺️ 建議學習路徑

- **完全新手**：1（架構）→ 2（YAML）→ 3（Pod/Namespace）→ 7（logs/labels 除錯）→ 8（Deployment）。先能建、能看、能除錯。
- **要讓應用「活得好」**：4（資源）→ 5（探針/設定）→ 6（Secret）。
- **有狀態與連線**：9（儲存）→ 10（網路）。
- **考 CKA/CKAD**：全部都要，特別練 3/4/7/8/10 的命令式速建與 `kubectl explain`。

## 🧩 搭配使用

- 範本在 `../templates/`（複製改 `<佔位符>` 即可 `kubectl apply`）。
- 輔助腳本在 `../scripts/preflight-check.sh`（動手前環境預檢）。
- 整體操作流程與鐵則請看技能主檔 `../SKILL.md`。
- 要「實際部署到雲上、建叢集、對外開放」→ 改用 `gke-deploy` 技能。
