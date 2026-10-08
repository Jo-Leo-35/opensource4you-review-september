---
course: Kubernetes FULL COURSE (Chad)
lesson: Lesson_4
part: Part 4
title: Kubernetes Resource Management – Requests & Limits
speaker: Chad（CKA/CKAD 認證講師，20 年教學經驗）
source_url: https://www.youtube.com/watch?v=t0-sj1mkdDg
duration: "約 00:12:11"
domains: [資訊科學, 雲原生, DevOps, 軟體工程]
level: 入門到中階（CKA/CKAD 基礎）
language: 繁體中文為主，保留 Kubernetes 英文術語
transcript_source: [[2025-08-08_t0-sj1mkdDg_Kubernetes-FULL-COURSE-Part-4-Kubernetes-Resource-Management-–-Requests-&-Limits.txt]]
---

# Kubernetes FULL COURSE：Lesson 4 — 資源管理：Requests 與 Limits（Resource Management – Requests & Limits）

> 來源：逐字稿 / SRT（YouTube，Chad 的 Kubernetes FULL COURSE Part 4）｜https://www.youtube.com/watch?v=t0-sj1mkdDg
> 講者：Chad（CKA/CKAD 認證講師，自述 20 年教學經驗）
> 時長：約 00:12:11
> 領域：資訊科學／雲原生／DevOps／軟體工程
> 難度：入門到中階（CKA/CKAD 基礎）
> 學習目標：理解 Kubernetes 為何要做**資源治理（resource governance）**，學會用 `kubectl top`（配合 metrics-server）觀測用量，並能在 Pod manifest 的 container 層級設定 `requests`（保證下限）與 `limits`（硬上限），再用 namespace 的 `ResourceQuota` 做整體配額圍籬；同時建立「Kubernetes 的一切都透過 API 溝通、升級叢集就是升級 API」的心智模型。

## 📌 一句話總覽

本講回答一個維運上非常務實的問題：**在一個由許多節點（node）聚合而成的 Kubernetes 叢集裡，如何避免某些容器把 CPU 與記憶體吃光、又不讓其他容器餓死？** 講者先用一個玩笑式的假 API version（`honka bonka`）帶出一個常被忽略卻很痛的現實——**Kubernetes 把一切都當成透過 API 溝通的資源（resource），升級叢集本質上就是升級它辨識、設定、管理各種資源的 API 能力**，所以昨天能跑的 manifest 今天升級後可能就報 `no matches for kind ... in version ...`，這就是 API 棄用（deprecation）與遷移（migration）的日常。接著進入主題：先用 `kubectl top`（需先部署 metrics-server）觀測 node 與 pod 的實際用量，再進到核心的兩個 container 層級旋鈕——**`requests`（排程時保證能拿到的資源下限，避免容器「餓死」）** 與 **`limits`（執行期的硬上限，避免容器「當豬」吃爆節點）**，並示範它們在 manifest 裡的縮排位置、CPU 的 `millicore`（毫核）單位、以及「limit 不得小於 request」的鐵律。最後把鏡頭拉高到 namespace 層級的 `ResourceQuota`，用「夜店保鑣（bouncer）」比喻說明配額如何逐一累加每個 Pod 的請求量，一旦超過上限就直接拒絕新 Pod 建立。本講在整個課程地圖中屬於「讓工作負載乖乖守規矩」的治理層，向前銜接 Pod/manifest 基礎（[[Lesson_3_Kubernetes_Pods_and_Manifests]]），向後連到 Deployment 的自動擴縮與健康檢查（[[Lesson_5_Kubernetes_Deployments]]）。

## 🧭 知識地圖（Knowledge Map）

- **前置知識**：
  - Pod、container、YAML manifest 的基本結構（`apiVersion` / `kind` / `metadata` / `spec` / `spec.containers`），以及 `kubectl apply -f`、`kubectl get/describe`。見 [[Lesson_3_Kubernetes_Pods_and_Manifests]]。
  - namespace 的概念（資源的邏輯隔離區）。
  - 容器（container）本質上是共用 host kernel 的行程群，CPU/記憶體是可被爭搶的有限資源。
- **本集核心**：
  - **API 版本與棄用**：`apiVersion` 的意義、升級叢集＝升級 API、deprecated API migration guide、欄位可能改名／新增／移除。
  - **觀測（observability）**：`kubectl top nodes/pods`、metrics-server（metrics API）、`--all-namespaces` / `-A`。
  - **資源治理三旋鈕**：`requests`（保證下限、影響排程）、`limits`（硬上限、影響執行期）、`ResourceQuota`（namespace 總配額）。
  - **單位**：memory 用位元組單位（如 Mi）、CPU 用 `millicore`（1 core = 1000m）。
  - **規則**：`limits ≥ requests`；`requests`/`limits` 是逐容器（container-by-container）設定。
- **後續會連到**：
  - Deployment / ReplicaSet 如何把這些 resource 設定套到多副本工作負載（[[Lesson_5_Kubernetes_Deployments]]）。
  - 健康檢查 probe（liveness / readiness）與 QoS class、OOMKilled、CPU throttling（[[Lesson_6_Kubernetes_Probes_and_Health]]）。
  - HorizontalPodAutoscaler（HPA）如何依 metrics 自動擴縮（依賴 metrics-server）。
  - 在 GKE 上實際部署與排查（[[gke-deploy]] skill）。
- **可跨領域連結**：作業系統的行程排程與 cgroups（資源隔離）、經濟學的配額／稀缺資源分配、排隊理論與容量規劃、SRE 的容量管理與過度承諾（overcommit）。

## 🎯 核心重點（Core Takeaways）

- **Kubernetes 把一切都當成透過 API 表達與管理的資源；升級叢集就是升級這些 API 的辨識與管理能力**，因此 manifest 中的 `apiVersion` 會隨版本演進而改變，昨天可行的 manifest 今天可能報 `no matches for kind ... in version ...`。
- **API 版本演進會帶來三種變化**：欄位可能「意義改變」、可能「新增」、可能「被移除」；官方的 *deprecated API migration guide* 會用點記法（dot notation，如 `spec.limited.nominalConcurrencyShares`）逐一標示變更，維運者必須在升級前對照修正。
- **叢集是所有節點聯網後聚合成的一個整體（aggregate/one whole）**，維運者必須「持續盯著資源被消耗多少」，並設下合理的「路標與護欄（guideposts and guardrails）」，確保用量不被突破。
- **`kubectl top` 是最 vanilla（原生、免裝花俏工具）的觀測手段，但它依賴 metrics API**；從零自建的叢集預設沒有，會報 `metrics API not available`，必須先套用 Kubernetes 官方 GitHub 提供的 metrics-server manifest 才能啟用。
- **metrics-server 這份 manifest 會建立一批具權限的 Pod 去「採集」其他 Pod 與 node 的資訊**，這些權限來自 ClusterRole、RoleBinding、ClusterRoleBinding（RBAC）；要等 `APIService metrics` 顯示 available/`True` 後才能用 `kubectl top`。
- **`kubectl top nodes` 顯示各 node 已用 CPU 與 memory 的百分比；`kubectl top pods` 只看目前 namespace**，跨所有 namespace 要加 `--all-namespaces`（或酷炫寫法 `-A`），是快速揪出「吃資源大戶（pigs）」的絕佳除錯工具。
- **資源治理是一條細線（fine line）**：容器需要資源才能活，不能餓死（starve）；但也不能放任它們變成「豬」吃掉超過所需的量——`requests` 與 `limits` 就是同時解決這兩端的旋鈕。
- **`requests` 是「保證」**：它向排程器承諾這個容器至少能拿到某個量的資源（給它「呼吸的氧氣」），避免容器因搶不到資源而餓死。
- **`limits` 是「硬上限（hard cap）」**：當容器失控、開始像流氓（rogue）般狂吃資源時，`limits` 為它能塞進嘴裡的資源量設下不可逾越的天花板。
- **`requests` 與 `limits` 是逐容器（container-by-container）設定的**，寫在該 container 底下的 `resources:` 區塊；YAML 的縮排層級（indentation）決定它套用到哪個 container，縮排錯就套錯地方。
- **CPU 用 `millicore`（毫核）計量：1 core = 1000 millicore（1000m）**；`millicore` 讓你能精細指定「我只要用 CPU 時間的一小部分」，例如 `250m` 代表四分之一核，不必獨佔整顆核。
- **memory 用位元組單位**（講者示範 request 65、limit 130「等於加倍」，單位為 MB/Mi）；`limits` 必須至少等於 `requests`，把 limit 設得比 request 小會直接報錯。
- **`ResourceQuota` 是 namespace 層級的護欄**：它像夜店門口的保鑣（bouncer），先加總 namespace 內既有 Pod 已「請求／限制」的資源量，一旦新 Pod 會使總量超過配額，該 Pod 立即被「拒絕建立（denied）」，根本進不了叢集。
- **配額的攔截發生在「建立當下、即時（immediately）」**：不是等到執行期才踩煞車，而是在 admission 階段就算帳；因此可用 `kubectl ... --watch` 即時看到 Pod 被接受或被拒。
- **`ResourceQuota` 可以非常細（granular）**：能分別針對 memory 的 requests 總和與 limits 總和設上限（講者示範 400 MB requests、500 MB limits），逐個 Pod 累加，直到再加一個就會超標即拒絕。

## 🔑 關鍵字與術語表（Keywords & Glossary）

| 術語 | 原文 / 符號 | 說明 |
|---|---|---|
| API 版本 | `apiVersion` | manifest 頂層欄位，宣告此資源要用哪個 API group/version 來解讀（如 `v1`、`apps/v1`） |
| 資源種類 | `kind` | manifest 指定的物件型別（如 `Pod`、`Deployment`、`ResourceQuota`） |
| 棄用 | deprecation / deprecated | 舊 API 版本被標記將移除；升級後可能出現「no matches for kind ...」 |
| API 遷移指南 | deprecated API migration guide | 官方文件，列出各版本間 API 版本升級與欄位變更 |
| 點記法 | dot notation | 用 `spec.limited.nominalConcurrencyShares` 這種路徑表示巢狀欄位 |
| 叢集 | cluster | 由多個 node 聯網聚合成的一個整體 |
| 節點 | node | 叢集中的一台（虛擬或實體）機器，提供 CPU/記憶體等資源 |
| 護欄 / 路標 | guardrails / guideposts | 講者對「資源用量上限與規範」的比喻 |
| 觀測工具 | `kubectl top` | 顯示 node/pod 即時 CPU 與 memory 用量的原生指令 |
| 指標伺服器 | metrics-server | 採集叢集資源用量、提供 metrics API 的元件；`kubectl top`、HPA 都依賴它 |
| 指標 API | metrics API / `APIService metrics` | 提供資源用量資料的 API；未部署時報 `metrics API not available` |
| 角色型存取控制 | RBAC | 由 ClusterRole / RoleBinding / ClusterRoleBinding 授權 Pod 存取叢集資訊 |
| 服務帳戶 | ServiceAccount | Pod 用來對 API server 表明身分的帳號（本講略過細節） |
| 所有命名空間 | `--all-namespaces` / `-A` | 讓 `kubectl top pods` 等指令跨全部 namespace 查詢 |
| 資源請求 | `requests` | 排程時保證容器可取得的資源下限 |
| 資源限制 | `limits` | 執行期容器可用資源的硬上限 |
| 資源區塊 | `spec.containers[].resources` | 在單一 container 下放 `requests` 與 `limits` 的位置 |
| 毫核 | millicore（`m`） | CPU 計量單位，1 core = 1000m；`250m` = 0.25 core |
| 記憶體單位 | Mi / MB | memory 以位元組單位表示（如 `65Mi`、`130Mi`） |
| 資源配額 | `ResourceQuota` | namespace 層級的資源總量上限物件 |
| 命名空間 | namespace | 叢集內資源的邏輯隔離區（本講以 `demo` 為例） |
| 監看 | `--watch` / `-w` | 讓 `kubectl` 持續即時輸出物件變化 |
| 餓死 / 失控 | starve / rogue / amok | 講者對「資源不足」與「資源狂吃」的擬人化描述 |
| QoS 類別 | QoS class（補充） | 依 requests/limits 設定分為 Guaranteed / Burstable / BestEffort（本講未點名，屬延伸） |
| 記憶體超限被殺 | OOMKilled（補充） | 容器超過 memory limit 時被 kernel 終止（延伸背景） |

## 📖 詳細筆記（Detailed Notes）

### 1. `apiVersion` 與「升級叢集＝升級 API」 [00:00:00–00:02:44]
**本段回答的問題**：manifest 最上面那行 `apiVersion` 到底在幹嘛？為什麼升級叢集後舊 manifest 會突然壞掉？

- **場景設定（刻意搞笑）**：講者故意寫了一個不存在的 API 版本 `honka bonka`，模擬情境——「昨天」這份 manifest 還好好的，每個參數都正確；「今天」滾出了比昨天更新版本的叢集，manifest 突然不работ，冒出訊息 `There are no matches for kind pod in version honka bonka`。
- **核心機制**：**Kubernetes 的一切都透過 API 溝通**。所謂「升級 Kubernetes」，升的其實是它的 **API**——也就是它「辨識（recognize）、設定（configure）、管理（manage）各種資源」的能力，而這些能力會隨版本改變。
- **對維運者的含義**：升級叢集後必須更新 manifest 的 `apiVersion`。欄位可能：(1) 意義改變、(2) 新增、(3) 被移除。
- **官方工具**：*deprecated API migration guide*。講者以 v1.32 為例：一種叫 *flow control* 的資源，其 API 版本從 `v1beta3` → `v1`；並用**點記法**指出 `spec.limited.nominalConcurrencyShares` 的預設值有變。
- **文化梗**：沒人喜歡升級叢集（"such a huge pain"），這是與 Kubernetes 共事的「猛獸本性（nature of the beast）」。
- **關聯**：這段是本講的「維運現實」開場，提醒你 manifest 不是寫完就一勞永逸；接著才進入資源治理主題。

### 2. 資源管理開場：叢集是節點的聚合 [00:02:44–00:03:08]
**本段回答的問題**：為什麼需要「資源管理」這件事？

- **系統模型**：一個 Kubernetes cluster 是「所有聯網在一起的 node 聚合成的一個整體（an aggregate of all the nodes networked together to create one whole）」。資源（CPU、memory）總量是有限的、由眾 node 提供。
- **維運職責**：必須「持續盯著（constantly keeping an eye on）」有多少資源被消耗，並設下「合理的路標與護欄（reasonable guideposts and guardrails）」確保用量不被突破。
- **工程鏡頭（控制流）**：這裡點出治理的兩個層面——先要能「觀測（監控用量）」，再要能「限制（設上下限與配額）」，後續小節正是沿這兩條線展開。

### 3. 監控工具、`kubectl top` 與 metrics-server [00:03:08–00:04:39]
**本段回答的問題**：怎麼看叢集現在用了多少資源？為什麼 `kubectl top` 一開始不能用？

- **工具光譜**：市面上有很多第三方工具可整合進 Kubernetes，有些「很漂亮、很視覺化（pretty and visual）」；但也有幾個在最陽春（vanilla）的環境就能用——**`kubectl top`** 就是其一。
- **常見故障**：若叢集是「從零自建（from scratch）」，`kubectl top` 多半會失敗，報錯 **`metrics API not available`**（指標 API 不存在）。
- **解法**：套用 Kubernetes 官方 **GitHub repo** 提供的 manifest（即 metrics-server）。
  - 它會建立一堆物件：一批 Pod 負責「採集、收割（gathering and harvesting）」其他 Pod 與 node 的資訊；還有 **ClusterRole、RoleBinding、ClusterRoleBinding** 授予這些 Pod 讀取的權限（RBAC）。
  - ServiceAccount 等細節本講略過（"can wait for a little later"）。
- **等待就緒**：需等 `APIService metrics` 回報 up and running / `True`，`kubectl top` 才會生效。
- **關聯**：metrics-server 也是 HorizontalPodAutoscaler（HPA）的資料來源，屬於觀測基礎設施；連到 [[gke-deploy]] 中「先確認 metrics 可用再做自動擴縮」。

### 4. `kubectl top nodes / pods / -A` 實戰 [00:04:39–00:05:57]
**本段回答的問題**：`kubectl top` 具體怎麼用？輸出看什麼？

- **`kubectl top nodes`**：顯示叢集內各 node 已使用的 CPU 與 memory「百分比（percentage of available）」——一眼看出哪台 node 快滿了。
- **`kubectl top pods`**：預設**只看目前 namespace**（與 `kubectl get` / `kubectl describe` 一致的行為）；若當前 namespace 沒 Pod 就看不到東西。
- **跨 namespace**：`kubectl top pods --all-namespaces`，或「想耍酷」用 `-A`（大寫 A）。
- **實例觀察**：講者叢集裡的「大戶（the pigs）」是兩個 **calico** Pod——這是意料之中，因為 calico 是負責網路、把 node 串在一起的元件。
- **用途**：這是快速找出「哪些 Pod 失控狂吃資源」的除錯利器，有助於判斷該如何修正。
- **關聯**：找出吃資源大戶後，下一步自然是替它們設 `requests`/`limits`（第 5–10 節）。

### 5. requests vs limits 的直覺：別餓死、也別當豬 [00:05:57–00:06:40]
**本段回答的問題**：為什麼要在 manifest 裡多加資源參數？要解決什麼張力？

- **鋪陳**：接下來要「編輯 Pod manifest、加更多參數」，讓 Pod 在**資源消耗**這件事上「守規矩（behave themselves）」。
- **核心張力（fine line）**：
  - Pod 裡的 container **需要資源才能活**——不能讓它們「餓死（starve to death）」。
  - 但也**不能讓它們變成豬（pigs）**，吃掉超過所需的量。
- **對應兩個旋鈕**：這條細線的兩端，正好對映到接下來的 `requests`（防餓死）與 `limits`（防狂吃）。
- **工程鏡頭（trade-off）**：這是典型的資源配置 trade-off——保底 vs 封頂；設太緊會扼殺效能、設太鬆會危及鄰居（noisy neighbor）。

### 6. `requests`：資源保證下限 [00:06:40–00:06:59]
**本段回答的問題**：`requests` 到底保證了什麼？

- **定義**：`requests` 是你在 manifest 裡設的參數，**保證（guarantees）你的 Pod 能拿到某個量的資源**。
- **為什麼重要**：否則容器會餓死；講者比喻為「給它們呼吸所需的氧氣（give them the oxygen they need to breathe）」。
- **工程鏡頭（補充背景，非逐字稿原文）**：`requests` 主要影響**排程（scheduling）**——排程器（scheduler）依各 node 「可分配資源減去已被 request 的量」來決定 Pod 放哪台；一個 node 上所有 Pod 的 request 總和不得超過該 node 容量。這解釋了為何 request 是「保證」：排程器已為它預留。
- **關聯**：request 太小會被塞到資源不足的 node 導致爭搶；太大會浪費節點空間、降低裝箱密度（bin-packing）。

### 7. `limits`：資源硬上限 [00:06:59–00:07:24]
**本段回答的問題**：`limits` 防的是什麼情況？

- **定義**：容器「失控、像流氓般狂吃資源（go amok / rogue amounts）」並非罕見；`limits` 就是為「container 能塞進嘴裡的資源量」設下**硬上限（hard cap）**。
- **直覺**：講者說這比 requests 更好懂——「我們大概都能認同」有些行程就是會失控。
- **工程鏡頭（補充背景，非逐字稿原文）**：CPU 與 memory 的 limit 行為不同——
  - 超過 **CPU limit** → 被**節流（throttled）**，不會被殺，只是變慢。
  - 超過 **memory limit** → 容器被 **OOMKilled**（記憶體無法「借一下就還」，只能終止）。
  - 這是排查 `CrashLoopBackOff` / `OOMKilled` 的關鍵知識，詳見 [[gke-deploy]] 的故障排查段落。
- **關聯**：limit 保護的是「鄰居與 node 本身」，避免單一容器拖垮整台機器。

### 8. 在 manifest 裡放 `resources`：縮排與逐容器設定 [00:07:24–00:07:58]
**本段回答的問題**：這兩個參數在 YAML 裡放哪、套用到誰？

- **關鍵：縮排層級（indentation）**：講者強調要看清楚縮排——這個區塊是加在「某一個特定的 container」底下。
- **逐容器（container-by-container）**：`requests` 與 `limits` 是**逐容器設定**的，不是整個 Pod 一次設定。一個 Pod 有多個 container 時，各自要各設一份。
- **結構**：在 container 下的 `resources:` 區塊裡，放 `requests:` 與 `limits:` 兩個子區塊；再往下縮排才是實際的 `cpu` / `memory` 值。
- **工程鏡頭（資料結構）**：對照 [[Lesson_3_Kubernetes_Pods_and_Manifests]] 的 manifest 骨架，`resources` 是 `spec.containers[i]` 陣列元素的一個欄位，YAML 縮排即是這棵樹的層級；縮排錯 = 套到錯誤的節點或變成無效欄位。

### 9. 設定 `requests` 值：memory 與 millicore CPU [00:07:58–00:08:49]
**本段回答的問題**：怎麼寫具體的 request 數字？CPU 的單位為什麼怪怪的？

- **memory request**：`requests` 底下設「最低要多少資源」，講者示範 memory「至少 65（MB/Mi）」。
- **CPU 的 millicore**：Kubernetes 特有的計量方式——**1 core = 1000 millicore（1000m）**。
  - `millicore`（毫核）讓你能「進一步細分」：宣告「我只想用 CPU 時間的一小部分，不要一整顆核」。
  - 示範：至少要拿到 **250 millicore（250m）** 的 CPU（＝0.25 核）。
- **工程鏡頭（單位精度）**：memory 是「整數位元組」概念（Mi/Gi），CPU 是「時間分片比例」概念（可小數/毫核）。兩者語意不同，這也解釋了為何超限行為不同（見第 7 節補充）。
- **關聯**：這些 request 值就是排程器替 Pod 預留的量；下一節設 limit。

### 10. 設定 `limits` 值：`limits ≥ requests` 的鐵律 [00:08:49–00:09:18]
**本段回答的問題**：limit 怎麼設？有什麼硬性規則？

- **鐵律**：**`limits` 必須至少等於 `requests`**（limit ≥ request）。若把 limit 設得比 request 還小，`kubectl` 會直接**報錯**。
- **示範值**：CPU limit 設 **500（millicore，500m）**、memory 設 **130**，講者說 memory「基本上是加倍（doubling it，65→130）」。
- **結果**：這樣的物件此時建立「就會成功（it would work）」。
- **工程鏡頭（不變量 invariant）**：`request ≤ limit` 是一個系統不變量，違反即被 API server 於 admission 階段拒絕——這是 fail-fast 設計，把錯誤擋在建立前而非執行期。
- **關聯**：接著把治理層級從「單容器」拉高到「整個 namespace」的 `ResourceQuota`。

### 11. `ResourceQuota` 回顧：namespace 層級的規則 [00:09:18–00:09:58]
**本段回答的問題**：除了逐容器設限，怎麼替整個 namespace 設總量上限？

- **回顧設定**：稍早在某 namespace 上加了 **`ResourceQuota`**，規定「任何在此 namespace 建立的 Pod 都得遵守規則」。
- **即時演示**：用 `--watch`（監看）即時觀察；接著在 **`demo` namespace** 裡建立一個 Pod。
- **即時攔截**：Pod 一建立，`ResourceQuota` **立刻（immediately）** 記帳——「你已經消耗了 x 量資源、已經請求了那麼多」。
- **累加規則**：你可以繼續建更多一模一樣的 Pod，但**只能建到達配額上限為止**。
- **關聯**：這是「多租戶（multi-tenant）／團隊隔離」的核心手段——用 namespace + quota 防止某團隊吃光叢集。

### 12. `ResourceQuota` 如何攔截：夜店保鑣比喻 [00:09:58–00:10:50]
**本段回答的問題**：配額擋 Pod 的邏輯像什麼？

- **保鑣比喻（bouncer）**：`ResourceQuota` 就像站在夜店門口的保鑣。當店內人數達到「消防法規（fire code）」允許的上限，保鑣就開始「把人往外趕（turning people away）」，說「不行、滿了、回家吧」。
- **對應到 Pod**：建立 Pod 也一樣——配額額滿後，新的 Pod 就被擋在門外、不得進入。
- **工程鏡頭（准入控制 admission control，補充）**：這個「進門檢查」對應 Kubernetes 的 admission 階段——在物件真正被寫入 etcd 前先驗證，超額即拒。這也是為何攔截是「即時、建立當下」而非執行期。
- **關聯**：比喻幫助初學者理解「配額是准入時的門檻」，不是事後才回收。

### 13. `ResourceQuota` 逐 Pod 累加與拒絕示範 [00:10:50–00:12:03]
**本段回答的問題**：配額如何逐個 Pod 累加？超過會怎樣？

- **細緻度（granular）**：`ResourceQuota` 可以非常細——能分別對 memory 的請求與限制設上限。講者示範配額：「memory 最多用到 **400 MB**、limits **500 MB**」。（註：此處數字為 quota 演示，與第 9–10 節單一 Pod 的 CPU/記憶體示範是不同情境。）
- **累加演示**：
  1. 建一個 request 100、limit 200 的 Pod。
  2. 再建一個同樣 request 100、limit 200 的 Pod——此時 limits 累計已達 **400/500**（用掉允許量的一大部分）。
  3. 若再建一個 Pod，總量會**超過 500**——這個 Pod 就會被**拒絕（denied）**，不允許在叢集中建立。
- **要點**：配額是「所有 Pod 該資源請求／限制的總和」對上限，逐一累加、先到先算、額滿即拒。
- **收尾**：影片以背景音樂（Music）結束本 Part。
- **關聯**：這與第 6 節「request 是排程保證」呼應——quota 管的正是 request/limit 的**總和**，因此設 request/limit 不只影響單容器，也會消耗 namespace 的配額預算。

## 🧪 例子、案例與應用

- **假 API 版本 `honka bonka`**：講者用不存在的版本製造 `no matches for kind pod in version honka bonka` 錯誤，具體演示「升級叢集後 apiVersion 對不上」的實況——用來記住「升級前先查 migration guide」。
- **v1.32 的 flow control API 遷移**：`v1beta3 → v1`、`spec.limited.nominalConcurrencyShares` 預設值改變，示範真實世界的欄位級（field-level）變更。
- **calico Pod 是資源大戶**：`kubectl top pods -A` 揭示 calico（CNI 網路元件）吃最多資源，說明「系統元件本身也是資源消費者」。
- **單一 container 的 requests/limits 範例**：memory 65→130、CPU 250m→500m，示範「保底/封頂」與「limit≥request」。
- **demo namespace 的配額攔截**：兩個 (request 100 / limit 200) 的 Pod 把 limits 撐到 400/500，第三個被拒——把抽象配額變成看得見的「額滿拒絕」。

### 可直接複習的 YAML manifest（教學重建）

> 以下為依講者敘述重建的教材範例，數值與講者示範一致；`apiVersion` 等以常見穩定值示意。

```yaml
# pod-with-resources.yaml —— 在單一 container 上設定 requests / limits
apiVersion: v1
kind: Pod
metadata:
  name: resource-demo
  namespace: demo
spec:
  containers:
    - name: app                 # requests/limits 是「逐容器」設定
      image: nginx:stable
      resources:
        requests:               # 保證下限（影響排程）
          memory: "65Mi"
          cpu: "250m"           # 250 millicore = 0.25 core（1 core = 1000m）
        limits:                 # 硬上限（執行期）；必須 >= requests
          memory: "130Mi"       # 約為 request 的兩倍
          cpu: "500m"
```

```yaml
# resource-quota.yaml —— namespace 層級的總配額（保鑣）
apiVersion: v1
kind: ResourceQuota
metadata:
  name: demo-quota
  namespace: demo
spec:
  hard:
    requests.memory: "400Mi"    # 所有 Pod 的 memory requests 總和上限
    limits.memory:   "500Mi"    # 所有 Pod 的 memory limits 總和上限
    # 亦可加：requests.cpu / limits.cpu / pods 數量等
```

### 常用 kubectl 指令速查

```bash
# 1) 先部署 metrics-server（官方 GitHub manifest），否則 kubectl top 會報 metrics API not available
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 2) 確認 metrics APIService 就緒（顯示 True 才能用 top）
kubectl get apiservices | grep metrics

# 3) 觀測資源用量
kubectl top nodes                     # 各 node 的 CPU/memory 使用百分比
kubectl top pods                      # 只看目前 namespace
kubectl top pods --all-namespaces     # 跨全部 namespace
kubectl top pods -A                   # 同上，酷炫寫法

# 4) 套用帶 resources 的 Pod 與配額，並即時監看攔截
kubectl apply -f resource-quota.yaml
kubectl apply -f pod-with-resources.yaml
kubectl get pods -n demo --watch      # 觀察被接受 / 被 quota 拒絕
kubectl describe resourcequota demo-quota -n demo   # 查看已用 / 上限
```

## ⚠️ 常見誤解與反例

- **誤解：manifest 寫好就永遠能用。**
  - 釐清：升級叢集會升級 API，`apiVersion` 可能失效、欄位可能改名/新增/移除；升級前務必對照 deprecated API migration guide。
- **誤解：`kubectl top` 是內建、隨裝隨用。**
  - 釐清：它依賴 metrics API；未部署 metrics-server 時會報 `metrics API not available`，必須先套用官方 manifest 並等 APIService 就緒。
- **誤解：`kubectl top pods` 會列出所有 Pod。**
  - 釐清：預設只看**目前 namespace**（與 get/describe 相同）；要全叢集得加 `--all-namespaces` / `-A`。
- **誤解：`requests` 就是容器實際會用到的量。**
  - 釐清：`requests` 是「排程保證的下限」，容器實際可以用更多（直到撞到 `limits`）；request 主要影響「排到哪台 node」。
- **誤解：`limits` 可以隨便設得比 `requests` 小。**
  - 釐清：`limits ≥ requests` 是硬性規則，違反會直接報錯，物件建不起來。
- **誤解：CPU 的 `250m` 是「250 顆核」或「250 MB」。**
  - 釐清：`m` 是 millicore，`250m` = 0.25 核；memory 才用 Mi/MB。
- **誤解（補充）：超過 memory limit 只是變慢。**
  - 釐清：超過 **CPU limit** 是被節流（變慢）；超過 **memory limit** 會被 **OOMKilled**（直接終止）。
- **誤解：`ResourceQuota` 在容器超用時才踩煞車。**
  - 釐清：它在**建立當下（admission）** 就按 requests/limits 總和記帳，超額即拒新 Pod，不是等執行期。

## 🧠 深層理解

1. **核心直覺是什麼？** 把「有限的叢集資源」當成需要治理的公共財：先能看見（`kubectl top`），再對單一容器設保底（requests）與封頂（limits），最後對整個 namespace 設總量護欄（ResourceQuota）。
2. **它解決了什麼問題？** 兩個對立風險——容器「餓死」（拿不到資源）與容器「當豬」（吃爆節點拖垮鄰居）；同時解決多租戶下「某團隊吃光叢集」的公平性問題。
3. **它犧牲或忽略了什麼？** 設定 requests/limits 需要事先了解工作負載的資源輪廓（profiling）；設太緊扼殺效能、太鬆失去保護意義。配額也可能在容量充足時仍擋下 Pod（保守但安全）。
4. **它和哪些概念容易混淆？** requests（排程保證）vs limits（執行硬頂）；`kubectl top`（即時用量）vs requests/limits（宣告的配置）；container 層級的 limits vs namespace 層級的 ResourceQuota。
5. **教給初學者的比喻是什麼？** requests＝「保留座位」、limits＝「吃到飽的封頂盤數」、ResourceQuota＝「夜店保鑣按消防人數上限放人」。
6. **現實使用的最大限制是什麼？** 數值難一次抓準——過度承諾（overcommit，limits 總和 > node 容量）能提高利用率但有 OOM/節流風險；保守設定則浪費資源。實務上需靠 metrics 觀測 + 迭代調整（甚至用 VPA/HPA 輔助）。

## 🕒 時間軸索引（Timeline Index）

- 00:00:00–00:02:44：`apiVersion` 與「升級叢集＝升級 API」；`honka bonka` 玩笑、deprecated API migration guide、欄位變更。
- 00:02:44–00:03:08：資源管理開場——叢集是節點聚合，需設路標與護欄。
- 00:03:08–00:04:39：監控工具總覽、`kubectl top` 需 metrics-server、RBAC 授權、等待 metrics APIService 就緒。
- 00:04:39–00:05:57：`kubectl top nodes/pods`、`--all-namespaces`/`-A`、calico 是資源大戶。
- 00:05:57–00:06:40：requests vs limits 的直覺——別餓死也別當豬。
- 00:06:40–00:06:59：`requests` 定義（保證下限、氧氣）。
- 00:06:59–00:07:24：`limits` 定義（硬上限、防狂吃）。
- 00:07:24–00:07:58：在 manifest 裡加 `resources`——縮排與逐容器設定。
- 00:07:58–00:08:49：設 requests 值——memory 65、CPU millicore（1 core=1000m、250m）。
- 00:08:49–00:09:18：設 limits 值——limit≥request、500m/130，建立成功。
- 00:09:18–00:09:58：`ResourceQuota` 回顧——namespace 規則、demo namespace、即時記帳。
- 00:09:58–00:10:50：保鑣比喻——額滿即拒。
- 00:10:50–00:12:03：逐 Pod 累加演示——400/500、第三個 Pod 被拒；片尾 Music。

## 💡 重點問答 / 自我測驗

- **Q：為什麼升級 Kubernetes 叢集後，原本能用的 manifest 可能報 `no matches for kind ...`？**
  A：因為升級叢集本質是升級其 API（辨識/設定/管理資源的能力），`apiVersion` 與欄位會演進；舊版本可能被棄用移除，需依 migration guide 更新。
- **Q：`kubectl top` 為何在全新自建叢集上失敗？如何修？**
  A：它依賴 metrics API，報 `metrics API not available`；需套用官方 metrics-server manifest，等其 Pod 就緒、APIService 顯示 True 後才能用。
- **Q：metrics-server 的 manifest 為何要建立 ClusterRole/RoleBinding/ClusterRoleBinding？**
  A：那些是 RBAC 授權，讓採集用的 Pod 有權限讀取其他 Pod 與 node 的資訊。
- **Q：`kubectl top pods` 和 `kubectl top pods -A` 差在哪？**
  A：前者只看目前 namespace，後者（=`--all-namespaces`）跨全部 namespace。
- **Q：`requests` 和 `limits` 各自保證/限制什麼？**
  A：`requests` 保證容器排程時至少能拿到的資源（防餓死、影響排到哪台 node）；`limits` 是執行期硬上限（防狂吃、封頂）。
- **Q：`requests` 與 `limits` 是 Pod 層級還是 container 層級設定？**
  A：container 層級（container-by-container），寫在該 container 的 `resources` 區塊，縮排決定套用對象。
- **Q：`250m` CPU 是多少？1 core 等於多少 millicore？**
  A：250 millicore = 0.25 核；1 core = 1000 millicore。
- **Q：可以把 limit 設得比 request 小嗎？**
  A：不行，`limits` 必須 ≥ `requests`，否則報錯、物件建不起來。
- **Q：`ResourceQuota` 何時、以什麼方式攔截 Pod？**
  A：在建立當下（admission）即時記帳，累加 namespace 內所有 Pod 的 requests/limits，超過配額就拒絕新 Pod。
- **Q：兩個 (request 100/limit 200) 的 Pod 在 400/500 配額下，為何第三個被拒？**
  A：前兩個 limits 累計 400/500，第三個會使 limits 總和超過 500，超額即被 denied。
- **Q（比較題）：`kubectl top` 顯示的數字和 manifest 裡的 requests/limits 是同一回事嗎？**
  A：不是。`top` 是**即時實際用量**（來自 metrics-server）；requests/limits 是你**宣告的配置**（保證/上限）。兩者常需對照來調參。
- **Q（應用題，補充）：容器一直被 OOMKilled，該調哪個參數？**
  A：多半是 memory `limits` 太低（或程式漏記憶體）；先用 `kubectl top`/describe 觀察峰值，再上調 memory limit 或修程式。
- **Q（反例題）：為什麼「把所有 limits 設到超大」不是好主意？**
  A：limits 過大失去保護作用，且若 limits 總和超過 node 容量（overcommit），高峰時仍可能觸發 OOM/節流並影響鄰居。

## 🧩 跨領域連結

- **作業系統 ↔ Kubernetes 資源管理**：requests/limits 底層對應 Linux **cgroups** 的 CPU 配額與 memory 上限；OOMKilled 即 kernel OOM killer。理解 OS 行程排程與資源隔離有助於掌握 K8s 行為。
- **經濟學／稀缺資源分配 ↔ ResourceQuota**：配額是典型的稀缺資源分配與外部性治理（防止 noisy neighbor 的「公地悲劇」），與課稅/限額思維相通。
- **排隊理論／容量規劃 ↔ overcommit**：limits 總和超過實體容量是「統計複用」下的過度承諾，與網路的 statistical multiplexing（見 [[Lecture_1_Network_Architecture_OSI_7_Layer]] 的資源共享段）異曲同工——賭的是「不會同時尖峰」。
- **SRE／可靠性工程 ↔ 觀測+護欄**：先觀測（metrics）再設護欄（quota/limit）是 SRE 容量管理的標準循環。
- **API 設計／版本演進 ↔ 軟體工程**：deprecated API migration 與 `apiVersion` 演進，是 API 向後相容性與 schema evolution 的實例，和 protobuf/資料庫 schema migration 同源。

## 🔗 延伸學習路徑

- **下一步應學**：
  - **QoS class**（Guaranteed / Burstable / BestEffort）——由 requests/limits 的設定組合決定，影響節點資源吃緊時誰先被驅逐（eviction）。
  - **LimitRange**——namespace 層級的「單一容器預設值/上下限」，與 ResourceQuota（總量）互補。
  - **HorizontalPodAutoscaler（HPA）**——依 metrics-server 提供的 CPU/memory 指標自動擴縮副本。
  - **健康檢查 probe**（liveness / readiness / startup）——與資源設定共同決定 Pod 穩定性，見 [[Lesson_6_Kubernetes_Probes_and_Health]]。
- **推薦關鍵字**：`resources.requests`、`resources.limits`、`millicore`、`metrics-server`、`kubectl top`、`ResourceQuota`、`LimitRange`、`QoS class`、`OOMKilled`、`CPU throttling`、`overcommit`、`deprecated API migration guide`。
- **相關資源**：
  - Kubernetes 官方文件：Managing Resources for Containers、Resource Quotas、metrics-server（GitHub: kubernetes-sigs/metrics-server）、Deprecated API Migration Guide。
  - CKA/CKAD 考綱中的「Application Resource Requirements」章節。
  - 本 repo 的 [[gke-deploy]] skill：在 GKE 上實作 requests/limits、排查 Pending/OOMKilled/CrashLoopBackOff。
- **在知識地圖中的位置**：本講是「工作負載治理層」的入門——上承 Pod/manifest 基礎（[[Lesson_3_Kubernetes_Pods_and_Manifests]]），下啟 Deployment 擴縮（[[Lesson_5_Kubernetes_Deployments]]）與自動化（HPA/VPA），是把「跑得起來」升級為「跑得穩、跑得公平」的關鍵一步。

> 校正說明（ASR 修正）：本逐字稿為自動轉錄（語言標記誤標為 Chinese，實際內容為英文口語），本筆記已將明顯的術語口語化寫法對映為標準寫法：「kube control top」→ `kubectl top`；「dash capital a」→ `-A`（`--all-namespaces`）；「millicore」保留原文並補上單位符號 `m`；「enroll bindings」→ RoleBinding；「API service metrics ... up and running true」→ metrics APIService 就緒（`True`）。API 版本 `honka bonka` 為講者刻意杜撰的示範用假版本，非真實 API，予以保留並註明。逐字稿中「limited / nominal concurrency shares」對應 flow control 資源的 `spec.limited.nominalConcurrencyShares` 欄位，已以點記法標準化。第 13 節配額示範的 400/500（MB）與第 9–10 節單一 Pod 的 65/130、250m/500m 屬不同示範情境，已於文中註記以免混淆；無法可靠還原之片段未予杜撰。
