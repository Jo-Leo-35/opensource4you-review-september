# Kubernetes FULL COURSE：Lesson 2 — Kubernetes YAML 與 Manifests 入門指南（YAML and Manifests - The Beginner's Guide）

> 來源：逐字稿 + SRT（YouTube，ASR 轉錄）｜https://www.youtube.com/watch?v=-JtRpHr9bGQ
> transcript_source: [[2025-08-08_-JtRpHr9bGQ_Kubernetes-FULL-COURSE-Part-2-Kubernetes-YAML-&-Manifests-–-The-Beginner’s-Guide.txt]]
> 講者：Chad（CKA/CKAD 認證講師，逾 20 年教學經驗）
> 時長：約 8 分 44 秒（00:00:00–00:08:44，本課程 Part 2）
> 領域：資訊科學／雲原生（Cloud Native）／DevOps／軟體工程
> 難度：入門（CKA/CKAD 基礎；YAML 與 manifest 讀寫）
> 學習目標：能讀懂 YAML 的兩種基本資料結構（list 與 dictionary）與縮排語意，理解 Kubernetes manifest 的四大頂層欄位（`apiVersion`、`kind`、`metadata`、`spec`），知道「宣告式（declarative）描述你要什麼」這個核心心智模型，並學會「從官方文件取得 manifest 範本、絕不從零手寫」的實務紀律，以及最容易踩雷的地方（大小寫、API 版本、image 名稱）。

## 📌 一句話總覽

本講回答的核心問題是：「在 Kubernetes 裡，我到底怎麼『告訴叢集我想要什麼』？」答案是寫一份 **manifest**——一個用 **YAML** 撰寫、宣告式（declarative）描述期望狀態（desired state）的檔案。講者用「到咖啡店點餐」的比喻切入：你不是自己走進廚房動手做，而是把「我要燕麥奶、要這些配料、留點空間」這張訂單交出去，剩下由店家（Kubernetes control plane）想辦法達成——這正是宣告式 API 的精神，也是它和傳統「一步步下指令」的命令式（imperative）操作的根本差異。為了讓初學者能真正讀寫 manifest，本講先花一半篇幅補齊 YAML 語法：兩種資料型別（**list/sequence** 用 `-`、**dictionary/mapping** 用 `key: value`）、值的型別（字串、布林、數字），以及 YAML 的靈魂——**縮排（indentation）代表歸屬（ownership）與巢狀（nesting）**。接著切回 Kubernetes，拆解所有 manifest 共通的骨架：頂層四欄位 `apiVersion`、`kind`、`metadata`、`spec`，並以最基本的 **Pod**（container 的 wrapper）manifest 為例，說明 `containers` 與 `ports` 為何是 list、`image` 名稱為何是最該小心的地方。它在整個課程地圖中的位置是「動手前的語言課」：Lesson 1 建立叢集架構與元件心智模型後，本講給你操作叢集的「書寫語言」，後續 Deployment、Service、ConfigMap 等所有資源，都是在這份骨架上長出來的。

## 🧭 知識地圖（Knowledge Map）

- **前置知識**：
  - Lesson 1 的叢集架構概念——control plane、API server、node、以及「一切都透過 API 溝通」（本講 `apiVersion` 一節會回呼此點）。
  - 容器（container）與映像檔（image）的基本概念（如 Docker、nginx image）。
  - 一點點文字編輯器經驗（講者示範用 Notepad++，靠縮排折疊觀察巢狀）。
- **本集核心**：
  - manifest = 宣告式描述「期望狀態」的檔案；咖啡店點餐比喻。
  - YAML 語法：list（`-`）、dictionary（`key: value` 與冒號）、值型別（string/boolean/number）。
  - 縮排即歸屬（ownership）與巢狀（nesting）；YAML 對縮排極度敏感。
  - manifest 頂層四欄位：`apiVersion`、`kind`、`metadata`、`spec`。
  - `kind` 大小寫敏感；`apiVersion` 對應不同 API group（Pod 用 `v1`）。
  - Pod 是 container(s) 的 wrapper；`containers` 與 `ports` 是 list。
  - 實務紀律：從 kubernetes.io 官方文件取得 manifest 範本，別從零手寫；`image` 名稱打錯會拉不到映像檔。
- **後續會連到**：
  - [[Lesson_3_Kubernetes_Pods]]（Pod 生命週期、多容器 Pod、probe）。
  - [[Lesson_4_Kubernetes_Deployments_and_ReplicaSets]]（Deployment/ReplicaSet manifest，`spec.template` 內嵌 Pod spec、label selector）。
  - Service、Ingress、ConfigMap、Secret、PV/PVC 的 manifest（皆共用同一骨架）。
  - `kubectl apply -f`、`kubectl explain`、`kubectl get -o yaml` 等指令化操作。
  - 本 repo 技能 [[gke-deploy]]（在 GKE 上實際套用這些 manifest、排查 Pod 問題）。
- **可跨領域連結**：
  - 宣告式 vs 命令式 ↔ 函數式程式設計（描述「是什麼」而非「怎麼做」）、SQL（宣告查詢意圖）、基礎設施即程式碼（IaC，如 Terraform）。
  - YAML/縮排語意 ↔ Python 的縮排語法、資料序列化格式（JSON、TOML）。
  - 期望狀態 + 調和迴圈（reconciliation loop）↔ 控制理論的閉迴路回饋控制。

## 🎯 核心重點（Core Takeaways）

- **manifest 是「宣告式的訂單」**：你不描述「怎麼做」，只描述「我要什麼（期望狀態）」，然後把這份描述交給 Kubernetes，由 control plane 負責把叢集實際狀態調和成你要的樣子——就像在咖啡店點餐，你報配方而不進廚房。
- **manifest 用 YAML 撰寫**，因此讀寫 Kubernetes 的前提是先看懂 YAML；YAML 的設計目標是「對人眼友善、易讀（readable to human eyeballs）」。
- **YAML 只有兩種核心資料結構**：**list/sequence（序列）**——每個元素前面加一個 `-`，順序有意義；**dictionary/mapping（映射）**——由 `key: value` 組成，順序不重要（unlike a list）。
- **冒號 `:` 分隔 key 與 value**；value 可以是不同型別：字串（如 `chocolate`）、布林（`true`/`false`）、數字（如 `1000`）。
- **縮排（indentation）在 YAML 中至關重要，它代表「歸屬 / ownership」**：縮排在某個 key 之下的所有內容，都是那個 key 的 value；縮排錯了語意就全錯（這是 YAML 最常見的錯誤來源）。
- **結構會複合、會巢狀（they compound, they get nested）**：一個 key 的 value 可以是另一組 dictionary，也可以是一個 list（例如 `ice cream` 底下有 `flavor`、`brand`，還有一個縮排的 `toppings` list）。
- **所有 manifest 頂端都有三個共通欄位**：`apiVersion`、`kind`、`metadata`（再加上主體 `spec`，構成四大骨架）。學會一個 manifest，其他的就大致看得懂——「longer and scarier ones they all work pretty much exactly the same」。
- **`kind` 指定物件類型且大小寫敏感（case sensitive）**：把 `Pod` 寫成小寫 `pod` 會直接出大問題——這類小地方最容易咬人。
- **`metadata` 放物件的識別與描述資訊**，例如名稱，以及之後會用到的 **label** 與 **annotation**（都縮排在 `metadata` 之下）。
- **Kubernetes 叢集內不只一個 API，而是很多個 API**（回呼 Lesson 1「一切透過 API 溝通」）；不同 API 負責不同類型的物件。**`v1` 是最原始、存在最久的 API，負責建立 Pod**；`apiVersion` 填錯會報「此 API version 不支援你要建的物件類型」的錯。
- **`spec`（specification 的縮寫）是「下訂單」的地方**：你在這裡描述物件要被「建成什麼樣」。
- **Pod 只是一個或多個 container 的 wrapper（包裝）**：`spec.containers` 是一個 list（每個元素以 `-` 開頭），所以一個 Pod 可以裝多個 container；`ports` 同理也是 list。
- **`image` 名稱是 Pod manifest 裡最該小心的欄位**：只要有 typo（如把 `nginx` 打錯），Kubernetes 會找不到映像檔而報錯——「forewarned is forearmed（先知先防）」。
- **實務鐵律：manifest 要從官方來源取得，絕不從零手寫（never write them from scratch）**：到 kubernetes.io 搜尋你要的資源（如 pod），取第一個結果、往下捲，就能找到各種現成範本與說明，複製後再修改。

## 🔑 關鍵字與術語表（Keywords & Glossary）

| 術語 | 原文 / 符號 | 說明 |
|---|---|---|
| 資訊清單／宣告檔 | manifest | 用 YAML 撰寫、描述你想要 Kubernetes 建立之物件的檔案；本質是「期望狀態的描述」 |
| 宣告式 | declarative | 只描述「要什麼結果」，不描述「怎麼一步步做」；Kubernetes 的核心操作模型 |
| 命令式 | imperative | 相對概念：一步步下指令要系統做動作（如 `kubectl run`）；本講未明講，為對照補充 |
| 期望狀態 | desired state | manifest 所描述的目標狀態；control plane 持續調和實際狀態向它靠攏 |
| YAML | YAML（逐字稿口語作 "yml"）| 一種對人眼友善的資料序列化格式；Kubernetes manifest 的撰寫語言 |
| 列表／序列 | list / sequence | YAML 資料型別之一；每個元素前加 `-`，順序有意義 |
| 字典／映射 | dictionary / mapping | YAML 資料型別之一；由 `key: value` 組成，順序不重要 |
| 鍵值對 | key-value pair | dictionary 的組成單位；以冒號 `:` 分隔 key 與 value |
| 縮排 | indentation | YAML 表達巢狀與歸屬（ownership）的機制；極度敏感，錯了語意即錯 |
| 巢狀 | nesting | 一個值本身又是 list 或 dictionary，層層包在其他 key 之下 |
| 布林值 | boolean | 值型別之一：`true` / `false` |
| API 版本 | `apiVersion` | manifest 頂層欄位；指定用哪個 Kubernetes API group／版本建立此物件（Pod 用 `v1`） |
| 類型 | `kind` | manifest 頂層欄位；指定物件類型（如 `Pod`、`Deployment`），**大小寫敏感** |
| 中繼資料 | `metadata` | manifest 頂層欄位；放名稱、label、annotation 等識別與描述資訊 |
| 規格 | `spec`（specification）| manifest 主體；描述物件「要被建成什麼樣」 |
| 標籤 | label | 掛在 `metadata` 下的 key-value 標記，用於選取／分組物件（本講點名、後續深入） |
| 註記 | annotation | 掛在 `metadata` 下的非識別性附註資訊 |
| Pod | Pod | Kubernetes 最小可部署單位；一個或多個 container 的 wrapper |
| 容器 | container | Pod 內實際跑應用的執行單元；`spec.containers` 是一個 list |
| 映像檔 | image | container 依據的映像檔（如 `nginx`）；`image` 欄位名稱要精準，打錯拉不到 |
| 通訊埠 | port | container 對外開放的埠；`ports` 在 manifest 中是一個 list |
| kubectl | kubectl | Kubernetes 命令列工具；以 `kubectl apply -f <file>` 套用 manifest（本講未示範，實務補充） |
| API server | API server | control plane 元件，所有 manifest 都送到此處被接收與驗證（回呼 Lesson 1） |

## 📖 詳細筆記（Detailed Notes）

> 說明：本講為約 8 分 45 秒的入門片段，內容以「YAML 語法 + manifest 骨架」為主。以下依講者實際推進順序切分小節；標註 ⊕ 之處為配合工程鏡頭補入的延伸（YAML/kubectl/排查），非逐字稿原文，會明確標示。

### 1. 什麼是 manifest？「宣告式的訂單」比喻 [00:00:00–00:00:43]
**本段回答的問題**：在 Kubernetes 裡建立物件（object）到底是什麼意思？manifest 是什麼？

- **概念 / 定義**：很快就要開始建立「物件（objects）」了，而建立的方式是寫一個檔案，叫 **manifest**。manifest 就是「提供一串描述（a list of descriptions）：這些都是我想要的東西」。
- **推理 / 機制（咖啡店比喻）**：講者說這和「走進你家附近的咖啡店、在 app 上點餐」是同一個概念——你輸入「請用燕麥奶（oat milk）」「要這個、這個配料」「幫我留點空間」。重點是：**manifest 就是把「我想要什麼、我想把什麼組在一起」寫出來**，而不是你自己動手做。
- **工程鏡頭 ⊕**：這正是 Kubernetes 的**宣告式（declarative）**操作模型——你描述**期望狀態（desired state）**，交給 control plane 去達成，而不是像命令式（imperative）那樣一步步下指令。點餐者不進廚房，正對應「使用者不直接操作 node，只提交意圖」。
- **關聯**：這個「描述期望、交由系統實現」的心智模型貫穿整個 Kubernetes，是後續所有資源（Deployment、Service…）的共同哲學。

### 2. 為什麼先要學 YAML [00:00:43–00:00:57]
**本段回答的問題**：manifest 用什麼寫？為什麼要先補 YAML？

- **概念 / 定義**：問題在於——**manifest 是用 YAML 寫的**（逐字稿口語作 "yml"）。如果你不知道 YAML 怎麼寫、怎麼編輯，這一段就要講；如果你已經會 YAML，可以跳過這節。
- **推理 / 機制**：讀寫 Kubernetes 的前提是先看懂 YAML，否則連 manifest 的結構都無從下手。
- **關聯**：接下來三、四節都在鋪墊 YAML 語法，之後才切回 Kubernetes 骨架。

### 3. YAML 資料型別（一）：list / sequence，用 `-` [00:00:57–00:01:30]
**本段回答的問題**：YAML 有哪些資料型別？最簡單的那種長什麼樣？

- **概念 / 定義**：YAML 有兩種需要知道的資料型別，第一種比較簡單，叫 **list（列表）**，也叫 **sequence（序列）**，不同人有不同叫法。
- **推理 / 機制**：想像一張購物清單（grocery list），就是一堆你要買的東西。平常可能用逗號分隔，但**在 YAML 裡，list 的每個元素前面都要加一個「破折號 `-`」**，讓它更醒目、更易讀。
- **設計意圖**：YAML 的整體精神就是「讓人眼容易讀（readable to human eyeballs）」，`-` 的視覺提示正是為此。
- **YAML 範例 ⊕**：
  ```yaml
  # list / sequence：每個元素一個 dash
  groceries:
    - milk
    - eggs
    - bread
  ```
- **關聯**：稍後 Pod manifest 的 `containers` 與 `ports` 都是 list，這裡的 `-` 語感是理解那些欄位的關鍵。

### 4. YAML 資料型別（二）：dictionary / mapping，key-value [00:01:30–00:02:01]
**本段回答的問題**：第二種資料型別是什麼？它和 list 有何不同？

- **概念 / 定義**：第二種是 **dictionary（字典）**，也叫 **mapping（映射）**。它和 list 很不一樣——dictionary 的核心是**鍵值對（key-value pairs）**。
- **關鍵差異**：**dictionary 的 key-value 順序不重要（unlike a list）**；list 順序有意義，dictionary 沒有。
- **語法**：講者示意「藍色的是我的 keys、白色放我要填的 value」。例如 key 是 `flavor`，value 是 `chocolate`——**用冒號 `:` 把 key 和 value 分開**。
- **YAML 範例 ⊕**：
  ```yaml
  # dictionary / mapping：key: value，順序不影響語意
  flavor: chocolate
  brand: Hershey's
  ```
- **關聯**：manifest 的頂層欄位（`apiVersion`、`kind`…）本身就是一組 dictionary 的 key-value。

### 5. YAML 的值型別：字串、布林、數字 [00:02:01–00:02:45]
**本段回答的問題**：value 可以放哪些型別的資料？

- **概念 / 定義**：value 可以是各種型別。講者以「買冰淇淋」延伸：
  - **字串**：如 `flavor: chocolate`、`brand: Hershey's`。
  - **日期／字串**：如「不希望比 June 30th 更早過期」→ 一個到期日 value。
  - **布林（boolean）**：如 `true`。
  - **數字**：如「一桶大約 1000 大卡」→ `calories: 1000`。
- **重點**：注意「冒號 `:` 分隔 key 與 value」這件事在各種型別下都成立。
- **YAML 範例 ⊕**：
  ```yaml
  flavor: chocolate      # 字串
  expiration: 2024-06-30 # 日期（YAML 會辨識為日期字面量）
  organic: true          # 布林
  calories: 1000         # 數字
  ```
- **限制 / 誤區 ⊕**：YAML 會做隱式型別推斷——例如 `yes`/`no`/`on`/`off` 可能被解讀成布林（此為知名的 "Norway problem"）；不確定時可用引號強制成字串。此為工程補充，非逐字稿。

### 6. 巢狀與縮排：indentation 代表 ownership [00:02:45–00:03:44]
**本段回答的問題**：多個 key-value 怎麼組成「更大的一個東西」？縮排在其中扮演什麼角色？

- **概念 / 定義**：資料結構會**複合、變難、變巢狀（they compound, get nested）**。`flavor`、`brand`、`expiration` 這些其實都在描述「同一個冰淇淋」。
- **推理 / 機制**：於是可以把 **`ice cream` 當成 key**，而上述那一整包描述就是 `ice cream` 的 value。怎麼表達「這一整包都是 `ice cream` 的 value」？——**靠縮排（indentation）**。
- **核心命題**：**「縮排在 YAML 中至關重要，它意味著歸屬（ownership）」**。講者示範在 Notepad++ 裡用折疊（collapse）按鈕，把縮排在某 key 下的整塊資料收起來，很直觀地看出「這整塊都是這個 key 的 value」。
- **YAML 範例 ⊕**：
  ```yaml
  ice_cream:          # key
    flavor: chocolate   # 以下三行縮排 → 都歸屬於 ice_cream
    brand: Hershey's
    expiration: 2024-06-30
  ```
- **限制 / 誤區**：縮排錯位 = 歸屬錯 = 語意全錯。這是 YAML（與 Kubernetes manifest）最常見的錯誤來源。⊕ 補充：YAML 縮排一律用空格、不可用 Tab。

### 7. 巢狀 list：toppings 縮排在 key 之下 [00:03:44–00:04:40]
**本段回答的問題**：如果一個 key 的 value 本身是一個 list，怎麼寫？

- **概念 / 定義**：真正有趣的是「巢狀的值中還有值（nested values inside of others）」。在 `ice cream` 之下寫了 `flavor`、`brand`，但還想加上「我要哪些配料（toppings）」。
- **推理 / 機制**：`toppings` 是一個 **list**——可能要 sprinkles（彩糖）、fudge（軟糖醬）、cherry（櫻桃）、whipped cream（鮮奶油）。注意：**這串 `-` 的 list 縮排在 `toppings` 之下，而 `toppings` 本身又是一個縮排在 `ice cream` 之下的 key**。
- **總結命題**：看 manifest 時，**任何你看到的縮排或破折號都是有原因的（there for a reason）**——它們精確地編碼了「誰屬於誰」。
- **YAML 範例 ⊕**：
  ```yaml
  ice_cream:
    flavor: chocolate
    brand: Hershey's
    toppings:          # 這個 key 的 value 是一個 list
      - sprinkles
      - fudge
      - cherry
      - whipped cream
  ```
- **關聯**：這個「dictionary 裡包 list、list 裡再包 dictionary」的巢狀模式，就是所有 Kubernetes manifest 的結構本質。

### 8. 製作 manifest 的原則：從官方來源取得，別從零手寫 [00:04:40–00:05:20]
**本段回答的問題**：實際要做一份 manifest，該怎麼起手？

- **實務鐵律**：**「絕對、絕對不要嘗試從零手寫（Never ever try to write them from scratch）」**。第一步永遠是**從來源取得 manifest 範本**。
- **機制 / 步驟**：打開 Kubernetes 官方網頁（kubernetes.io），搜尋你要做的東西（例如 `pods`）；通常點第一個搜尋結果、往下捲，就會看到各種資源在不同用途下的 manifest 範本，還附「為什麼、怎麼運作」的說明。
- **推理**：官方範本已經把必填欄位、正確結構、正確 `apiVersion` 都寫好，複製後改成自己的值，遠比從零手寫不易出錯。
- **工程鏡頭 ⊕**：另一個等價來源是 `kubectl explain <resource>` 查欄位文件，或 `kubectl get <resource> <name> -o yaml` 匯出既有物件當範本。此為實務補充。
- **關聯**：呼應下一節——因為所有 manifest 結構高度一致，範本可高度複用。

### 9. manifest 的通用結構與可學習性 [00:05:20–00:05:38]
**本段回答的問題**：manifest 那麼多種，要一個一個學嗎？

- **核心命題**：好消息是——**即使是更長、更嚇人的 manifest，運作方式幾乎都一模一樣（they all work pretty much exactly the same）**。一旦你學會一個 manifest 怎麼運作，很多其他的就開始講得通了。
- **推理**：因為它們共用同一套頂層骨架與 YAML 語法，差別只在 `spec` 裡的細節。
- **關聯**：這說明了「先精通一個最基本的 Pod manifest」的學習策略價值——它是所有其他資源的縮影。

### 10. 頂層三欄位總覽：apiVersion、kind、metadata [00:05:38–00:05:44]
**本段回答的問題**：所有 manifest 頂端固定有哪些欄位？

- **概念 / 定義**：所有 manifest 頂端都會看到這三個值：**`apiVersion`、`kind`、`metadata`**。
- **工程鏡頭 ⊕**：加上主體 **`spec`**，即構成 Kubernetes 物件的四大骨架（`apiVersion` + `kind` + `metadata` + `spec`）。`spec` 在稍後幾節登場。
- **關聯**：以下三節逐一拆解 `kind`、`metadata`、`apiVersion`。

### 11. kind：物件類型，且大小寫敏感 [00:05:44–00:06:01]
**本段回答的問題**：`kind` 是什麼？有什麼陷阱？

- **概念 / 定義**：`kind` 相當自明——它告訴我們「這是哪一種物件（what kind of object）」，例如 `Pod`。
- **關鍵陷阱**：**`kind` 大小寫敏感（case sensitive）**。把 `Pod` 寫成小寫 `pod` 就會出「大大的問題（big big problem）」。
- **推理 / 教訓**：正是這種小地方會咬你，而你會很快學到教訓。⊕ Kubernetes 內建資源的 `kind` 慣例是 PascalCase（`Pod`、`Deployment`、`ReplicaSet`、`ConfigMap`）。
- **關聯**：與後面 `image` 名稱一樣，屬於「打字精準度」類的常見失敗點。

### 12. metadata：識別與描述資訊（labels、annotations 的家）[00:06:01–00:06:19]
**本段回答的問題**：`metadata` 放什麼？

- **概念 / 定義**：`metadata` 相當直接。再次注意 YAML 的縮排——**任何縮排在 `metadata` 之下的東西都屬於 metadata 區塊**。
- **推理 / 延伸**：所以之後處理 **label** 與 **annotation** 時，它們也會放在 `metadata` 之下。
- **工程鏡頭 ⊕**：`metadata` 最常見的必填是 `name`（物件在 namespace 內的唯一名稱）；`labels` 用於選取／分組（後續 Deployment 的 selector 會靠它），`annotations` 放非識別性的附註（如工具用的中繼資訊）。
- **關聯**：label 是 Kubernetes「以選擇器綁定物件」機制的基礎，會在 Deployment/Service 章節大量登場。

### 13. apiVersion：多個 API，v1 建立 Pod [00:06:19–00:07:09]
**本段回答的問題**：`apiVersion` 為什麼有趣？填錯會怎樣？

- **回呼 Lesson 1**：還記得談叢集架構時說過「Kubernetes 裡一切都透過 API 溝通」嗎？重點是——**叢集裡不只一個 API，而是很多個 API**。
- **概念 / 機制**：這些不同的 API 各自負責「設定與操作不同類型的物件」。**`v1` 是最原始、存在最久的 API，它擅長建立 Pod**。
- **關鍵陷阱**：`apiVersion` 值一定要填對，否則會得到類似「API version ⋯ 無法支援你要建立的物件類型」的錯誤。
- **工程鏡頭 ⊕**：不同資源屬於不同 API group，例如 Pod/Service/ConfigMap 用核心組 `v1`，Deployment/ReplicaSet 用 `apps/v1`，Job/CronJob 用 `batch/v1`。填錯 group 或版本就會被 API server 拒絕。
- **關聯**：`apiVersion` + `kind` 一起決定「送到哪個 API 端點、建哪種物件」，是 API server 路由與驗證的依據。

### 14. spec：規格，你的「訂單」 [00:07:09–00:07:27]
**本段回答的問題**：`spec` 是什麼？

- **概念 / 定義**：`spec` 是 **specification（規格）** 的縮寫。這是你「下訂單（put in your order）」的地方——**描述「我想要這個物件被建成什麼樣」**。
- **工程鏡頭 ⊕**：`spec` 就是「期望狀態」的具體內容；不同 `kind` 的 `spec` schema 不同（Pod 的 `spec` 有 `containers`，Deployment 的 `spec` 有 `replicas`、`selector`、`template`）。
- **關聯**：呼應第 1 節的咖啡店比喻——`spec` 就是你報給店家的那張配方。

### 15. Pod 是 container(s) 的 wrapper：containers 是 list [00:07:27–00:08:03]
**本段回答的問題**：Pod 的 `spec` 裡裝什麼？為什麼 `containers` 前面有 `-`？

- **概念 / 定義**：記住——**Pod 只是一個或多個 container 的 wrapper（包裝）**，你可以放不只一個 container。
- **推理 / 機制（回呼 YAML）**：看 `containers` 那行的第一個字元是一個 **`-`**。記得嗎？**`-` 代表 list 裡的元素**——這意味著 `containers` 是一個 list，你可以放進「一串 container」。想放多個就再加一個 `-` 元素即可（講者示意「這是 nginx，這是另一個 xyz」）。
- **YAML 範例 ⊕（單容器與多容器對照）**：
  ```yaml
  spec:
    containers:
      - name: web        # 第一個 container（list 第一個元素）
        image: nginx
      - name: sidecar    # 第二個 container（再加一個 dash）
        image: busybox
  ```
- **關聯**：這把第 3 節的 list 語法與 Kubernetes 具體欄位接了起來，也預告了「多容器 Pod（sidecar 模式）」的後續主題。

### 16. ports 也是一個 list [00:08:03–00:08:13]
**本段回答的問題**：除了 `containers`，還有哪些欄位是 list？

- **概念 / 定義**：`-` 的意義適用於任何 list，**包括 `ports`**——「這個 container 開了哪些 port？來列一張清單」。
- **YAML 範例 ⊕**：
  ```yaml
  spec:
    containers:
      - name: web
        image: nginx
        ports:
          - containerPort: 80    # ports 是 list，每個埠一個 dash
          - containerPort: 443
  ```
- **關聯**：再次印證「list 與 dictionary 巢狀複合」是 manifest 的通用結構。

### 17. image 名稱：最該小心的欄位（typo → 拉不到映像檔）[00:08:13–00:08:44]
**本段回答的問題**：Pod manifest 裡最容易出事、最該謹慎的是哪個欄位？

- **核心命題**：在 Pod manifest 的所有欄位中，**最該小心的就是 `image`**——映像檔名稱一定要精準正確。
- **推理 / 後果**：只要有任何 typo（講者說「像我剛剛那樣打錯」），就會有麻煩——Kubernetes 會去找那個（錯的）名字（例如把 `nginx` 打成別的），找不到映像檔就報錯。
- **教訓**：「這種事每個人都會遇到，但 **forewarned is forearmed（先知先防、有備無患）**」。
- **工程鏡頭 ⊕**：image 名稱／tag 錯誤在實務上表現為 Pod 卡在 `ImagePullBackOff` 或 `ErrImagePull`；排查用 `kubectl describe pod <name>` 看 Events。相關排查屬 [[gke-deploy]] 技能範圍。
- **關聯**：與第 11 節 `kind` 大小寫、第 13 節 `apiVersion` 併列為三大「打字精準度」失敗點。

## 🧪 實作範例（Hands-on：YAML manifest 與 kubectl）

> 說明：以下皆為**教學示範**（非逐字稿原文引用），把本講第 10–17 節的四大骨架（`apiVersion`／`kind`／`metadata`／`spec`）與 YAML 語法落地成一份可實際 `kubectl apply` 的最小 Pod manifest，並示範對應的指令流程。所有繁中皆為行內註解（`# ...`），欄位名與指令保留英文原文。

### 步驟 1：寫一份最小可用的 Pod manifest

先把本講的四大頂層欄位組成一份最小 Pod。這對應第 10 節（頂層三欄位＋`spec`）、第 15 節（`containers` 是 list）、第 16 節（`ports` 是 list）。把以下內容存成 `pod.yaml`：

```yaml
# pod.yaml — 教學示範：最小可用的 Pod manifest
apiVersion: v1          # 核心 API（v1）負責建立 Pod；填 apps/v1 會被拒（對應第 13 節）
kind: Pod               # 大小寫敏感！必須是 Pod，寫成 pod 會直接失敗（對應第 11 節）
metadata:
  name: my-first-pod    # Pod 在 namespace 內的唯一名稱
  labels:               # label 縮排在 metadata 之下（對應第 12 節）
    app: web            # 之後 Service/Deployment 會用 selector 靠 label 選取此 Pod
spec:                   # 你的「訂單」：描述期望狀態（對應第 14 節）
  containers:           # 這是一個 list，故每個元素以 dash 開頭（對應第 15 節）
    - name: web
      image: nginx:1.27 # ⚠️ 最該小心的欄位：名稱／tag 打錯 → ImagePullBackOff（對應第 17 節）
      ports:            # ports 也是一個 list（對應第 16 節）
        - containerPort: 80   # 容器對外開放的埠，每個埠一個 dash
```

### 步驟 2：宣告式套用並觀察狀態

呼應第 1 節的「宣告式訂單」比喻——你只提交 `pod.yaml` 這份期望狀態，剩下交給 control plane。用 `kubectl apply -f` 送出，再用 `kubectl get pods` 觀察是否 `Running`：

```bash
# 把 manifest 交給叢集（宣告式：描述你要什麼，不描述怎麼做）
kubectl apply -f pod.yaml

# 觀察 Pod 是否進入 Running；若卡在 ImagePullBackOff / ErrImagePull 多半是 image 名稱打錯
kubectl get pods

# 想看更多細節（節點、IP、重啟次數）時加 -o wide
kubectl get pods -o wide
```

### 步驟 3：不必硬背欄位——用 `kubectl explain` 查官方文件

呼應第 8 節「別從零手寫、善用官方來源」的鐵律。`kubectl explain` 直接在終端機查詢某欄位的官方 schema 說明，是「取代硬記」的實務利器：

```bash
# 查 Pod 的 spec 底下有哪些欄位（會列出 containers、volumes、restartPolicy... 及型別）
kubectl explain pod.spec

# 可逐層往下鑽，例如看 containers 這個 list 的元素有哪些欄位
kubectl explain pod.spec.containers

# --recursive 一次展開整棵欄位樹，適合快速掃描完整結構
kubectl explain pod.spec --recursive
```

### 步驟 4：把既有物件匯出成 YAML 當範本

呼應第 8 節「從來源取得 manifest」的另一等價做法——用 `-o yaml` 把叢集裡跑著的物件匯出成 YAML，就得到一份帶預設值、可複製再改的範本：

```bash
# 匯出既有 Pod 的完整 YAML（含 Kubernetes 自動補上的預設欄位與 status）
kubectl get pod my-first-pod -o yaml

# 實務技巧：套用前先 dry-run + 產生乾淨範本，避免縮排/欄位錯誤才真的送出
kubectl apply -f pod.yaml --dry-run=client -o yaml
```

### 常見踩雷對照（本講三大「打字精準度」失敗點）

| 你可能寫成 | 正確寫法 | 後果 |
|---|---|---|
| `kind: pod` | `kind: Pod` | 大小寫敏感，小寫直接被拒（第 11 節） |
| `apiVersion: apps/v1`（建 Pod） | `apiVersion: v1` | Pod 屬核心組 `v1`，填錯 group 報「不支援該物件類型」（第 13 節） |
| `image: nignx`（typo） | `image: nginx:1.27` | 拉不到映像檔，Pod 卡在 `ImagePullBackOff`（第 17 節） |

```bash
# 當 Pod 卡住時，第一件事永遠是看 Events（image / 排程 / 資源問題都在這）
kubectl describe pod my-first-pod
```

## 🧪 例子、案例與應用

- **咖啡店點餐比喻（宣告式的核心）**：在 app 點一杯客製飲料——燕麥奶、指定配料、留點空間——你只報「要什麼」，不進廚房。對應：manifest 描述期望狀態，control plane 負責實現。這是理解宣告式 API 最貼近生活的入口。
- **冰淇淋 YAML（YAML 結構的完整範例）**：`ice_cream` 這個 key 底下用縮排歸屬 `flavor`、`brand`、`expiration`，再用縮排的 `toppings` list 裝配料。這個例子一次示範了「dictionary + 巢狀 + list + 值型別（字串/日期/布林/數字）」全部語法。
- **最小 Pod manifest（把全部概念落地）**⊕：
  ```yaml
  apiVersion: v1          # 核心 API，負責 Pod
  kind: Pod               # 大小寫敏感，必須是 Pod
  metadata:
    name: my-first-pod
    labels:
      app: web            # label 掛在 metadata 之下
  spec:                   # 你的「訂單」
    containers:           # 這是一個 list
      - name: web
        image: nginx:1.27 # 名稱要精準，否則 ImagePullBackOff
        ports:
          - containerPort: 80
  ```
- **套用與觀察（kubectl 實務）**⊕：
  ```bash
  kubectl apply -f my-first-pod.yaml   # 宣告式套用 manifest
  kubectl get pods                     # 觀察是否 Running
  kubectl describe pod my-first-pod    # 看 Events，排查 image 等問題
  kubectl explain pod.spec.containers  # 查某欄位的官方文件（取代硬記）
  ```

## ⚠️ 常見誤解與反例

- **誤解：manifest 是一步步的操作腳本。**
  - **釐清**：不是。manifest 是**宣告式**的——它描述「最終要什麼（期望狀態）」，不是「先做 A 再做 B」的命令序列。實現過程由 control plane 的調和迴圈負責。
- **誤解：YAML 縮排只是排版好看，多幾格少幾格沒差。**
  - **釐清**：縮排在 YAML 中**代表歸屬（ownership）與巢狀**，是語意的一部分。縮排錯位會讓欄位掛錯父層，語意完全不同（且 YAML 只能用空格、不能用 Tab）。
- **誤解：`kind` 寫 `pod` 或 `Pod` 都行。**
  - **釐清**：`kind` **大小寫敏感**，必須是 `Pod`。小寫會直接失敗。
- **誤解：Kubernetes 只有一個 API，`apiVersion` 隨便填 `v1` 就好。**
  - **釐清**：叢集內有**很多個 API group**。Pod 用 `v1`，但 Deployment 要 `apps/v1`、Job 要 `batch/v1`。填錯會被 API server 拒絕。
- **誤解：`containers` 是單一物件，只能放一個容器。**
  - **釐清**：`containers` 是一個 **list**（前面有 `-`），Pod 可以包多個 container（sidecar 模式）。
- **誤解：image 名稱小 typo 無所謂，Kubernetes 會猜。**
  - **釐清**：不會猜。名稱錯就拉不到映像檔，Pod 會卡在 `ImagePullBackOff`／`ErrImagePull`。
- **誤解（工程補充）：`yes`/`no` 寫在 YAML 裡是字串。**
  - **釐清**：YAML 可能把它們推斷成布林（Norway problem）。需要字串時請加引號。

## 🧠 深層理解

1. **核心直覺是什麼？** manifest = 一張「我要什麼」的訂單，用 YAML 這種對人友善的格式寫成；縮排告訴系統「誰屬於誰」。你描述目標，叢集負責達成。
2. **它解決了什麼問題？** 讓「操作一個分散式叢集」變成「編輯一份可版本控管、可重現、可審查的文字檔」，而不是靠一連串易錯、難重現的手動指令。
3. **它犧牲或忽略了什麼？** 宣告式與 YAML 的代價是：對縮排／型別極度敏感（易出隱蔽錯誤）、缺乏程式語言的邏輯與變數（催生 Helm、Kustomize 這類模板工具）、以及初學者需要先跨過一道語法門檻。
4. **它和哪些概念容易混淆？** 宣告式 vs 命令式（`kubectl apply -f` vs `kubectl run`）；list vs dictionary（順序有意義 vs 無意義）；`apiVersion`（哪個 API）vs `kind`（哪種物件）。
5. **教給初學者的比喻是什麼？** 就是「咖啡店點餐」：你把配方（spec）交出去，店員（control plane）照單做好；你不需要、也不該自己衝進廚房。
6. **現實使用的最大限制是什麼？** YAML 縮排錯誤與欄位打字錯誤（`kind` 大小寫、`apiVersion`、`image` 名稱）是初學者最頻繁的失敗來源；因此本講的實務結論是「從官方範本複製、別從零手寫」，並善用 `kubectl explain` 與 `kubectl apply --dry-run`。

## 🕒 時間軸索引（Timeline Index）

- 00:00:00–00:00:43：manifest 是什麼——宣告式「訂單」與咖啡店比喻
- 00:00:43–00:00:57：manifest 用 YAML 寫；先補 YAML
- 00:00:57–00:01:30：YAML 型別一——list/sequence，用 `-`
- 00:01:30–00:02:01：YAML 型別二——dictionary/mapping，key-value 與冒號
- 00:02:01–00:02:45：值型別——字串、布林、數字
- 00:02:45–00:03:44：巢狀與縮排——indentation 代表 ownership（冰淇淋例）
- 00:03:44–00:04:40：巢狀 list——toppings 縮排在 key 之下；縮排/dash 皆有意義
- 00:04:40–00:05:20：實務鐵律——從官方文件取得 manifest，別從零手寫
- 00:05:20–00:05:38：manifest 結構高度一致，學一個懂全部
- 00:05:38–00:05:44：頂層三欄位——apiVersion、kind、metadata
- 00:05:44–00:06:01：kind——物件類型，大小寫敏感
- 00:06:01–00:06:19：metadata——縮排歸屬；label／annotation 的家
- 00:06:19–00:07:09：apiVersion——叢集有多個 API，v1 建 Pod，填錯報錯
- 00:07:09–00:07:27：spec——規格，你的「訂單」
- 00:07:27–00:08:03：Pod 是 container(s) 的 wrapper；containers 是 list
- 00:08:03–00:08:13：ports 也是 list
- 00:08:13–00:08:44：image 名稱要精準，typo 會拉不到映像檔

## 💡 重點問答 / 自我測驗

- **Q：manifest 是什麼？它體現了 Kubernetes 的哪種操作模型？**
  A：manifest 是用 YAML 撰寫、描述你想要之物件的檔案；它體現**宣告式（declarative）**模型——你描述期望狀態，由 control plane 負責實現，如同咖啡店點餐報配方而不進廚房。
- **Q：YAML 的兩種核心資料型別是什麼？各怎麼寫？**
  A：**list/sequence**——每個元素前加 `-`，順序有意義；**dictionary/mapping**——`key: value`，用冒號分隔，順序不重要。
- **Q：為什麼縮排在 YAML 中如此重要？**
  A：縮排代表**歸屬（ownership）與巢狀**；縮排在某 key 之下的內容都是那個 key 的 value，縮排錯位語意即錯（且只能用空格、不能用 Tab）。
- **Q：所有 manifest 的四大頂層骨架是哪些？**
  A：`apiVersion`、`kind`、`metadata`、`spec`。
- **Q：`kind` 有什麼必須注意的陷阱？**
  A：**大小寫敏感**。必須寫 `Pod` 而非 `pod`，否則失敗。
- **Q：`apiVersion` 為什麼重要？Pod 用哪個？**
  A：叢集內有多個 API group，各負責不同物件類型；填錯會被拒。Pod 用最原始的核心 API **`v1`**。
- **Q：`metadata` 之下會放哪些東西？**
  A：名稱（`name`），以及 **label** 與 **annotation** 等識別／描述資訊——都靠縮排歸屬於 metadata。
- **Q：`spec` 的角色是什麼？**
  A：`spec`（specification）是你「下訂單」的地方，描述物件要被建成什麼樣（期望狀態的具體內容）。
- **Q：為什麼 `containers` 和 `ports` 前面有 `-`？**
  A：因為它們是 **list**；`-` 標記 list 的元素，所以一個 Pod 可放多個 container、一個 container 可開多個 port。
- **Q：Pod manifest 裡最該小心的欄位是哪個？為什麼？**
  A：`image`。名稱有任何 typo 就會拉不到映像檔而報錯（實務上表現為 `ImagePullBackOff`）。
- **Q：製作 manifest 的實務鐵律是什麼？**
  A：**從官方來源（kubernetes.io）取得範本，絕不從零手寫**；複製現成範本再改，能避開大量結構與必填欄位錯誤。
- **Q（應用題）：把 `kind: pod`、`apiVersion: apps/v1` 拿去建 Pod 會發生什麼？**
  A：`kind` 小寫會失敗；`apps/v1` 不支援 Pod（Pod 屬核心組 `v1`），會得到「此 API version 不支援該物件類型」的錯誤。
- **Q（反例題）：若把 `ports` 寫成 `port: 80`（非 list）會怎樣？**
  A：schema 不符——`ports` 應是 list（元素含 `containerPort`），寫成單一 key-value 會驗證失敗或被忽略。

## 🧩 跨領域連結

- **宣告式 API ↔ 函數式程式設計 / SQL**：都強調「描述結果（what）」而非「描述步驟（how）」；SQL 你寫查詢意圖、引擎決定執行計畫，恰如 manifest 寫期望狀態、control plane 決定調和步驟。
- **期望狀態 + 調和迴圈 ↔ 控制理論**：Kubernetes controller 持續比較「期望狀態 vs 實際狀態」並修正，是典型的閉迴路回饋控制（feedback control）。
- **YAML 縮排語意 ↔ Python 縮排**：兩者都把「空白縮排」提升為語法／語意的一部分，對排版錯誤零容忍。
- **manifest ↔ 基礎設施即程式碼（IaC）**：與 Terraform、CloudFormation 同屬「用宣告式文字檔管理基礎設施」的思潮，帶來可版本控管、可審查、可重現的運維。
- **image 名稱錯誤 ↔ 相依性管理**：與套件管理（npm、pip）拼錯套件名的失敗同構——名稱是唯一定位符，錯一個字元就找不到目標。

## 🔗 延伸學習路徑

- **下一步應學**：
  - [[Lesson_3_Kubernetes_Pods]]——Pod 生命週期、多容器與 sidecar、`livenessProbe`/`readinessProbe`。
  - [[Lesson_4_Kubernetes_Deployments_and_ReplicaSets]]——Deployment `spec.template` 內嵌 Pod spec、label selector、滾動更新與回滾。
  - Service / Ingress / ConfigMap / Secret / PVC 的 manifest（皆共用本講骨架）。
- **推薦關鍵字**：`kubectl apply -f`、`kubectl explain`、`kubectl get -o yaml`、`--dry-run=client`、`ImagePullBackOff`、API group、desired state、reconciliation loop、Helm、Kustomize。
- **相關工具 / 資源**：
  - kubernetes.io 官方文件（manifest 範本的權威來源，本講強調）。
  - `kubectl explain <resource>.<field>`（不必硬背欄位）。
  - Helm、Kustomize（超越純 YAML 的模板化管理）。
  - 本 repo 技能 [[gke-deploy]]——在 GKE 實際套用 manifest、排查 Pod（Pending / CrashLoopBackOff / ImagePullBackOff / OOMKilled）。
- **在知識地圖中的位置**：本講是「動手前的語言課」——Lesson 1（[[Lesson_1_Kubernetes_Architecture]]，架構與元件）建立心智模型後，本講給你操作叢集的書寫語言（YAML + manifest 骨架），是後續所有資源型別章節的共同地基。

> 校正說明（ASR 修正）：逐字稿為自動轉錄，本筆記已將明顯同音／口語／誤植校正為標準術語——「yml」統一理解為 **YAML**（於術語表標註原口語）；「engine x / engine x2」校正為容器映像檔 **nginx**（講者示範多容器時口述的第二個 image 名稱無法可靠還原，僅以示意處理，未杜撰確切名稱）；示範中的第二個容器名 "xyz" 為講者隨口示意，非真實 image。「Dink（by hitting it with an indentation）」一句 ASR 明顯誤植，依上下文應為「（做法是）用縮排把它框起來」之意，已按語意重述、未逐字保留。所有時間戳對齊 SRT。無法可靠還原的片段未予杜撰。
