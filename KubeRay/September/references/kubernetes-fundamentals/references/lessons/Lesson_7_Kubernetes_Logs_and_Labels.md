# Kubernetes FULL COURSE Part 7：Kubernetes Logs 與 Labels — 故障排查與物件組織（Troubleshooting & Organization）

> 來源：逐字稿 + SRT（YouTube）｜https://www.youtube.com/watch?v=zSg82yiqLYU
> 講者：Chad（CKA/CKAD 認證講師，逐字稿自述 20 年教學經驗）
> 時長：約 14:46（單一影片，Kubernetes FULL COURSE Part 7）
> 領域：資訊科學／雲原生（Cloud Native）／DevOps／軟體工程
> 難度：入門到中階（CKA/CKAD 基礎）
> 學習目標：學會用 `kubectl logs` 觀察容器輸出以進行故障排查、理解 Kubernetes 日誌的「無常性（impermanence）」與其對第三方日誌方案的需求；並掌握 label（標籤）作為 key-value metadata 的建立、修改、覆寫、刪除，以及用 `-L` 欄位化顯示與 `-l` selector 批次選取物件，理解 label 是 Deployment / Service 等高階物件辨識 Pod 的核心機制。
> transcript_source: [[2025-08-08_zSg82yiqLYU_Kubernetes-FULL-COURSE-Part-7-Kubernetes-Logs-&-Labels-–-Troubleshooting-&-Organ.txt]]

## 📌 一句話總覽

本講處理維運 Kubernetes 叢集時兩件天天要用的基本功：**看日誌（logs）** 與 **貼標籤（labels）**，前者服務「故障排查（troubleshooting）與保住理智」，後者服務「大規模物件的組織與辨識」。日誌的核心事實是：Pod 內**每個 container 各自把 stdout 與 stderr 匯集成自己的 log**，`kubectl logs` 就是唯一用來讀取這些容器日誌的指令；它支援 `-c`（指定容器）、`--all-containers`、`-f`（即時串流）與 `--since`（時間窗）等旗標。但日誌有一個致命特性——**無常性**：當 Pod 被刪除，節點上 `/var/log/pods/...` 對應的目錄會被 kubelet 於下一輪清理（約每 60 秒）連同 log 一起刪除，這正是實務上要導入第三方日誌方案（如 EFK/Loki）的根本原因。標籤方面，講者用「牛的耳標（ear tag）」比喻：label 是掛在任何物件（從 Pod 到 Node）上、可自由定義的 **key-value metadata**，目的在於**分組、檢視、批次操作一整組物件**。它可透過編輯 manifest 後 `kubectl apply`，或用 `kubectl label` 指令即時新增（命令列用 `=` 而非 `:`）、`--overwrite` 覆寫、加 `key-` 後綴刪除。`-L <key>` 把某個 label 攤成欄位，`-l <key>=<value>` 則是 **selector**，可從上百個 Pod 的乾草堆裡精準撈出帶特定 label 的「針」。這個 selector 機制正是後續 Deployment、Service 用來辨識自己該管哪些 Pod 的基礎，是全課程「控制器如何找到工作負載」的地基。

## 🧭 知識地圖（Knowledge Map）

- **前置知識**：Pod 與 container 的基本概念、Pod 內可有多個 container（multi-container Pod）、`kubectl` 基本指令（get / apply / create / delete）、YAML manifest 的 `metadata` / `spec` 結構、Linux 檔案系統與 `stdout`/`stderr` 概念。
- **本集核心**：
  - **Logs**：container = 日誌來源、`stdout`+`stderr`、`kubectl logs`、default container（依 container 列表順序）、`-c` / `--all-containers` / `-f` / `--since` 旗標、日誌無常性、`/var/log/pods/`、kubelet 清理週期、第三方日誌方案。
  - **Labels**：label = key-value metadata（耳標比喻）、可貼在任何物件、descriptive & unique 原則、`--show-labels`、透過 manifest+`apply` 或 `kubectl label` 管理、`=` vs `:`、`--overwrite`、`key-` 刪除、`-L` 欄位化、`-l` selector 批次選取。
- **後續會連到**：Deployment（透過 `selector.matchLabels` + Pod template 的 labels 管理 ReplicaSet/Pod）、ReplicaSet、Service（透過 `selector` 找 backend Pod 建立 Endpoints）、Ingress、`nodeSelector`/affinity（用 node label 排程）、namespace、annotations（另一種 metadata）、readiness/liveness probe 與 events 的排查組合技。
- **可跨領域連結**：資料庫索引與查詢（label selector ↔ 二級索引 / `WHERE` 條件）、集合論（selector = 子集合篩選）、可觀測性工程（observability：logs/metrics/traces 三支柱）、資料生命週期與備份（ephemeral 儲存 ↔ 冷/熱資料保存）、畜牧業耳標追蹤系統（metadata 標記法）。

## 🎯 核心重點（Core Takeaways）

- **每個 container 各自產生自己的 logs，內容就是該 container 的 `stdout` 與 `stderr`**；Pod 若有多個 container，就有多份 log。這是 Kubernetes 日誌模型的最底層事實：容器只要把要記錄的東西印到標準輸出，Kubernetes 就會替你收集。
- **`kubectl logs` 是專門且唯一用來讀取 Pod 內容器日誌的指令**，你不需要（也不能）告訴它「我要的是 Pod 的日誌」——這是它唯一會去查的東西，直接 `kubectl logs <pod>` 即可。
- **當一個 Pod 有多個 container 時，`kubectl logs <pod>` 預設回傳「第一個列出的 container」的日誌**（會顯示 `defaulted container ...` 提示）；container 在 manifest 中的排列順序具有語意——先列先建，也就成為預設被讀日誌的對象。
- **`kubectl logs` 高度多功能**：`-c <container>` 指定特定容器、`--all-containers` 一次輸出 Pod 內所有容器日誌、`-f`（follow）即時串流新產生的日誌、`--since=10s` 只看最近某時間窗內的日誌，這些旗標可組合使用。
- **Kubernetes 日誌具有「無常性（impermanence）」**：Pod 被刪除時會「清理自己」，其所有日誌一併被移除；日誌**不會**在 Pod 消失後自動長存，這是排查已崩潰/已刪除工作負載時最容易吃虧的地方。
- **容器日誌實際落在節點的 `/var/log/pods/<namespace>_<pod>_.../<container>/` 目錄下**，該目錄 root 保護、需 `sudo`；結構會依 Pod 名（含 namespace）與 container 名分子目錄，最底層才是 log 檔。
- **kubelet 大約每 60 秒巡一次做清理**：Pod 刪除後，其 `/var/log/pods` 目錄與內部所有日誌會在下一輪清理被刪掉（講者實測約 45 秒後消失）；因此「刪 Pod = 連帶刪日誌」，維運時要有意識。
- **正因日誌無常，實務上才需要第三方集中式日誌方案**（超出本講範圍，但這是它們存在的理由）：把日誌即時送出節點集中保存，避免隨 Pod 生命週期蒸發。
- **label（標籤）本質是掛在物件上的 key-value pair metadata**，講者認為叫「tags（標籤/標記）」其實比「labels」更貼切；用「牛耳標」比喻：把品種、脾性、農場、年齡等資訊標在耳標上以區分牛群裡的每頭牛。
- **label 可貼在任何物件上，從 Pod 一路到 Node 本身**；其目的（purpose）是能夠**分組（group）、檢視（view）、批次操作（operate）** 多個物件的某個子集合，是 Kubernetes 辨識物件的主要方式之一。
- **好的 label 要「descriptive（描述性）且 unique（有辨識度）」**；label 的 key 與 value 幾乎可以是任何你想要的值，但把錯的 label 貼到錯的物件上會導致「絕對不好的非預期後果」（unintended consequences），因為高階物件會依 label 動作。
- **新增/修改 label 有兩條路**：（1）編輯 manifest 的 `metadata.labels` 再 `kubectl apply`——Kubernetes 樂於對執行中的 Pod 套用這種合法變更；（2）用 `kubectl label` 指令即時操作。
- **命令列操作 label 用 `=`，不是 manifest 裡的 `:`**：`kubectl label pod <pod> key=value`；若 key 已存在會報錯（`key already has a value`），要改值必須加 `--overwrite`；刪除則用 `kubectl label pod <pod> key-`（key 後接減號）。
- **`kubectl get pods --show-labels` 顯示所有 label 欄；`kubectl get pods -L <key>` 把指定 key 攤成獨立欄位**，有該 label 的 Pod 顯示其 value、沒有的顯示空白，方便一眼比對「哪些 Pod 有此標、哪些沒有」。
- **`-l <key>=<value>` 是 label selector，可從上百個 Pod 中精準撈出符合條件的子集合**（「從乾草堆裡挑出你要的針」）；這正是 Deployment、Service 等物件辨識、鎖定目標 Pod 的底層機制，因此熟練操作 label 對後續學習至關重要。

## 🔑 關鍵字與術語表（Keywords & Glossary）

| 術語 | 原文 / 符號 | 說明 |
|---|---|---|
| 日誌 | logs | 容器輸出的紀錄，內容為該容器的 stdout 與 stderr |
| 標準輸出 / 標準錯誤 | stdout / stderr | 程式的標準輸出與錯誤輸出串流；Kubernetes 從這兩者收集容器日誌 |
| 容器 | container | Pod 內執行的最小運算單元；每個容器各自產生日誌 |
| 豆莢 | Pod | Kubernetes 最小可部署單元，可含一個或多個 container |
| 多容器 Pod | multi-container Pod | 一個 Pod 內含多個 container（本講 counter 範例含兩個） |
| 預設容器 | defaulted container | 多容器 Pod 中 `kubectl logs` 未指定 `-c` 時預設讀取的容器（列表第一個） |
| 記錄檔指令 | `kubectl logs` | 讀取 Pod 內容器日誌的專用指令 |
| 跟隨串流 | `-f` / `--follow` | 即時串流持續輸出新產生的日誌 |
| 指定容器 | `-c <container>` | 指定要讀取哪一個容器的日誌 |
| 全部容器 | `--all-containers` | 一次輸出 Pod 內所有容器的日誌 |
| 時間窗 | `--since=10s` | 只顯示最近某段時間內的日誌 |
| 無常性 | impermanence | 日誌隨 Pod 刪除而消失、不自動長存的特性 |
| 節點日誌目錄 | `/var/log/pods/` | 節點上實際存放容器日誌檔的目錄（root 保護） |
| 節點代理 | kubelet | 每個 Node 上的代理程式，負責 Pod 生命週期與定期清理（約每 60 秒） |
| 忙碌盒 | busybox | 輕量 Linux 工具映像，本講用來跑無限迴圈印出日期與計數 |
| 第三方日誌方案 | third party logging solution | 集中收集/保存日誌的外部工具（如 EFK、Loki），解決無常性 |
| 標籤 | label | 掛在物件上的 key-value metadata，用於分組/篩選（講者認為 tag 更貼切） |
| 鍵值對 | key-value pair | label 的組成形式，key 與 value 幾乎可任意定義 |
| 中繼資料 | metadata | 描述物件的附加資訊；manifest 的 `metadata` 區塊含 name、labels 等 |
| 顯示標籤 | `--show-labels` | `kubectl get` 旗標，額外顯示每個物件的所有 label |
| 標籤欄位 | `-L <key>` | 把指定 label key 攤成獨立欄位顯示（有值顯示 value，無則空白） |
| 標籤選擇器 | `-l <key>=<value>` / label selector | 依 label 篩選出符合條件的物件子集合 |
| 覆寫 | `--overwrite` | `kubectl label` 更新既有 key 的 value 時必須加的旗標 |
| 套用 | `kubectl apply` | 依 manifest 對（含執行中的）物件套用宣告式變更 |
| 命名空間 | namespace | 物件的邏輯隔離分組；日誌目錄名含 namespace（如 default） |
| 部署 | Deployment | 高階控制器，透過 label selector 管理其 Pod（本講預告） |
| 服務 | Service | 透過 label selector 找到 backend Pod 的抽象（本講預告） |
| 選擇器 | selector | 高階物件用來辨識「該管哪些 Pod」的 label 條件 |

## 📖 詳細筆記（Detailed Notes）

### 1. 為何要看日誌：故障排查的起點 [0:00:00–0:00:26]
**本段回答的問題**：Kubernetes 日誌是什麼？為什麼它如此重要？

- **概念 / 定義**：日誌（logs）對「troubleshooting（故障排查）以及單純保住你的理智」極其重要。運作方式是——**Pod 裡的每一個 container 都會產生自己的日誌**。
- **推理 / 機制**：一個 container 產生的日誌，永遠就是該 container 輸出的 **standard out（stdout，標準輸出）** 與 **standard error（stderr，標準錯誤）**。也就是說，容器內程式印到終端的東西，Kubernetes 就替你收集成日誌。
- **例子 / 應用**：程式排查的第一手線索通常就是日誌——想知道應用為何 crash、為何回傳錯誤，先看它印了什麼。
- **限制 / 誤區**：日誌只涵蓋容器「印到 stdout/stderr」的內容；若應用把 log 寫進容器內某個檔案而非標準輸出，`kubectl logs` 看不到（需另行處理）。
- **關聯**：這是後續一切 `kubectl logs` 操作的前提，也是排查 CrashLoopBackOff 等問題（見 [[gke-deploy]] skill 的 Pod 排查）的第一步。

### 2. 示範 manifest：一個 Pod、兩個 busybox 容器 [0:00:26–0:01:06]
**本段回答的問題**：怎麼做一個能觀察到「多容器各自日誌差異」的實驗？

- **概念 / 定義**：講者展示一份 manifest——**一個 Pod 裡有兩個 container**，兩者都跑 **busybox**（輕量 Linux 工具映像）。
- **推理 / 機制**：兩個容器都在一個近乎無限的迴圈裡印出「日期（date）」以及計數變數 `i` 的當前值。差別在節奏：一個容器**每印一次暫停 1 秒**，另一個**每印一次暫停 3 秒**。
- **例子 / 應用**：兩個容器分別命名為 **`count`**（每秒一筆）與 **`count-by-three`**（每三秒一筆）；Pod 名為 **`counter`**。因此我們預期看到兩個容器輸出頻率明顯不同——這就是用來示範「同一 Pod 內不同容器有各自獨立日誌」的最小實驗。
- **限制 / 誤區**：這是教學用的人造工作負載；真實應用的日誌節奏由業務邏輯決定。
- **關聯**：容器命名順序（count 在前）會決定第 3 節的「預設容器」行為。

### 3. `kubectl logs` 基礎與「預設容器」 [0:01:06–0:02:22]
**本段回答的問題**：多容器 Pod 上直接下 `kubectl logs` 會拿到誰的日誌？

- **概念 / 定義**：`kubectl logs` 是新指令，**唯一功能就是查 Pod 容器的日誌**，所以你不必（也無法）額外告訴它「這是某某的日誌」——直接 `kubectl logs counter` 即可。
- **推理 / 機制**：但 `counter` 有兩個容器，輸出誰的？實測輸出是「每秒印一次日期」——也就是 `count` 容器。往上捲會看到提示 `defaulted container count out of count and count-by-three`。**因為 `count` 在 manifest 中被列在第一個，先被建立，於是成為預設被讀日誌的容器。**
- **例子 / 應用**：
  ```bash
  kubectl logs counter
  # 輸出：defaulted container "count" out of: count, count-by-three
  # <日期> i=0
  # <日期> i=1   ← 約每秒一筆
  ```
- **限制 / 誤區**：**container 的排列順序具有語意**——不要以為多容器 Pod 隨便 `logs` 就能看到你關心的那個容器；預設只給第一個。
- **關聯**：要看非預設容器就得靠 `-c`（下一節）。

### 4. `kubectl logs` 的旗標：`-c`、`--all-containers`、`-f`、`--since` [0:02:22–0:03:41]
**本段回答的問題**：`kubectl logs` 有哪些好用選項？

- **概念 / 定義**：`kubectl logs` 非常多功能，知道所有選項能大幅幫助排查。
- **推理 / 機制與例子**：
  ```bash
  # 指定容器：看 count-by-three（每三秒一筆）
  kubectl logs counter -c count-by-three

  # 一次看 Pod 內所有容器日誌
  kubectl logs counter --all-containers

  # 即時串流（follow）：新日誌一產生就即時更新
  kubectl logs counter -c count-by-three -f

  # 時間窗：只看最近 10 秒的日誌
  kubectl logs counter -c count-by-three --since=10s
  # 因為每 3 秒一筆，10 秒內大約只有 3 筆
  ```
- **限制 / 誤區**：`-f` 會佔住終端持續輸出，需 Ctrl-C 結束；`--since` 用相對時間（如 `10s`、`5m`、`1h`），對排查「剛剛」發生的問題特別實用。
- **關聯**：這些旗標可組合（如 `-c ... -f --since=...`），是日常 debug 的核心工具箱。

### 5. 日誌的無常性（上）：刪 Pod 就刪日誌 [0:03:41–0:04:22]
**本段回答的問題**：日誌會永久保存嗎？

- **概念 / 定義**：日誌具有 **impermanence（無常性）**。當一個 Pod 被刪除，**該 Pod 會「清理自己」，連同它的所有日誌一起被移除**。
- **推理 / 機制**：日誌與 Pod 生命週期綁定——Pod 在，日誌在；Pod 消失，日誌隨之蒸發。這解釋了「為什麼人們要用第三方日誌方案來繞過這個問題」。
- **例子 / 應用**：講者提到這個 `counter` Pod 目前跑在 `node1` 上，接著要親自登入 `node1` 去看日誌實際存放位置。
- **限制 / 誤區**：不要假設「Pod 崩了、刪了之後還能慢慢回頭撈日誌」——若沒有集中收集，證據就沒了。
- **關聯**：直接導向第 6、7 節的節點日誌目錄與清理機制。

### 6. 日誌的無常性（中）：節點上的 `/var/log/pods` [0:04:22–0:06:04]
**本段回答的問題**：容器日誌實際存在節點的哪裡？目錄長怎樣？

- **概念 / 定義**：登入節點後進入 `/var/log` 目錄，裡面有個叫 **`pods`** 的目錄（root 保護，需 `sudo`）。
- **推理 / 機制**：`/var/log/pods` 內以 **`<namespace>_<pod-name>_<uid>`** 形式命名子目錄。講者找到 `counter`（在 `default` namespace）對應的目錄；同層還有其他跑在該節點上的 Pod。進入 `counter` 目錄後，看到**兩個子目錄 `count` 與 `count-by-three`**——正是 manifest 裡兩個容器的名字；每個容器子目錄裡才是實際的 **log 檔**。
- **例子 / 應用**：
  ```bash
  # 在節點上（教學用途，一般不需這樣做）
  sudo ls /var/log/pods
  # default_counter_...   <namespace>_<pod>_<uid>
  sudo ls /var/log/pods/default_counter_*/
  # count   count-by-three   ← 兩個容器各一目錄
  sudo ls /var/log/pods/default_counter_*/count/
  # 0.log   ← 實際日誌檔
  ```
- **限制 / 誤區**：這是「為了教學理解日誌如何運作」才手動登入節點；正常維運**應該用 `kubectl logs`**，而不是 SSH 進節點翻檔案。
- **關聯**：目錄結構「Pod → 容器 → log 檔」再次印證第 1 節「每容器各自產日誌」。

### 7. 日誌的無常性（下）：kubelet 的清理週期 [0:06:04–0:07:02]
**本段回答的問題**：Pod 刪除後日誌多久會被清掉？誰負責清？

- **概念 / 定義**：刪除 Pod 後，講者用 `watch` 觀察目錄何時消失。
- **推理 / 機制**：**大約每 60 秒（依叢集而定），kubelet 會「巡一輪」做清理**（clean up）等雜務；因此 Pod 刪除後，其 `/var/log/pods` 目錄與內部所有日誌只是「時間問題」就會被刪掉。實測約 **45 秒**後目錄消失（在 60 秒週期內合理）。
- **例子 / 應用**：
  ```bash
  kubectl delete pod counter
  watch sudo ls /var/log/pods/   # 約 45 秒後 counter 目錄消失
  ```
- **限制 / 誤區**：**清理你的 Pod = 清理隨附的所有日誌**，維運時務必有意識。第三方日誌工具（超出本講範圍）就是為了在日誌蒸發前把它送出保存。
- **關聯**：小結——你現在會用 `kubectl logs` 了；接下來換主題到 labels。

### 8. 標籤的比喻：Kubernetes 的「耳標（ear tag）」 [0:07:02–0:08:07]
**本段回答的問題**：label 到底是什麼概念？為什麼講者說它該叫 tag？

- **概念 / 定義**：講者用一頭牛開場（自嘲 visual jump scare），來自賓州 Hershey 的酪農區。他認為 Kubernetes 把這東西叫 **labels** 是糟糕的用詞，**叫 tags（標記）會貼切得多**。
- **推理 / 機制**：牛是牛群（herd）裡眾多成員之一，人們在牠們耳朵上掛 **ear tag（耳標）**，記錄品種（breed）、脾性（temperament）、所屬農場（farm）、年齡（age）——這就像是一種 **metadata**，幫助我們分類、把一頭牛與另一頭區分開。牛不是寵物，是「牲畜（cattle）」，是可管理的群體成員。
- **例子 / 應用**：Kubernetes 對待物件（尤其 Pod）正是這種「牲畜而非寵物（cattle, not pets）」哲學——Pod 是可替換的群體成員，靠 label 這種「耳標」來辨識與分組。
- **限制 / 誤區**：比喻是幫助理解；技術上 label 就是純粹的 key-value metadata，無關動物福利 😄。
- **關聯**："cattle, not pets" 是雲原生核心心智模型，貫穿 Deployment 的「Pod 可被隨時重建」設計。

### 9. 標籤的本質與用途：key-value metadata [0:08:07–0:09:22]
**本段回答的問題**：label 的形式與目的是什麼？

- **概念 / 定義**：我們把這些「耳標」稱為 labels，**可以貼在任何物件上，從 Pod 一路到 Node 本身**。label 沒什麼玄機——**就是單純的 key-value pairs（鍵值對）**。
- **推理 / 機制**：label 的**目的（purpose）是能夠對多個物件的一個子集合（subsection）一次性地分組（group）、檢視（view）、操作（operate）**，這是 Kubernetes 辨識物件的主要方式之一。
- **例子 / 應用**：manifest 的 `metadata` 底下有 `labels`，範例中放了四個 label，全都是 key-value pair：
  ```yaml
  metadata:
    name: some-pod
    labels:
      app: web
      tier: frontend
      env: prod
      team: platform
  ```
- **限制 / 誤區**：
  - key 與 value **幾乎可以是任何你想要的值**，但**最好的 label 是 descriptive（描述性）且 unique（有辨識度）** 的。
  - **要小心把錯的 label 貼到錯的物件上**——因為高階物件會依 label 動作，貼錯會造成「絕對不好的非預期後果（unintended consequences）」。
- **關聯**：可貼在 Node → 連到 `nodeSelector`/affinity 排程；子集合操作 → 連到第 13 節 selector。

### 10. 建立無標籤 Pod 與 `--show-labels` [0:09:22–0:10:01]
**本段回答的問題**：怎麼確認一個 Pod 目前有哪些 label？

- **概念 / 定義**：先做一個極簡單的 Pod（`demopod`，用 nginx 映像），manifest 裡**完全沒提到任何 label**。
- **推理 / 機制**：`kubectl get pods --show-labels` 會給出平常 `get pods` 的輸出，但**多一欄 `LABELS`**；因為 manifest 沒放 label，這欄顯示 `<none>`。
- **例子 / 應用**：
  ```bash
  kubectl apply -f demopod.yaml
  kubectl get pods --show-labels
  # NAME      READY   STATUS    ...   LABELS
  # demopod   1/1     Running   ...   <none>
  ```
- **限制 / 誤區**：`--show-labels` 把「所有 label」擠進一欄，label 多時可讀性差；要聚焦單一 key 用第 12 節的 `-L`。
- **關聯**：接著示範如何對這個空白 Pod 加上 label。

### 11. 管理標籤（方法一）：編輯 manifest + `kubectl apply` [0:10:01–0:10:43]
**本段回答的問題**：如何用宣告式方式改 label？

- **概念 / 定義**：先開一個即時串流 `kubectl get pods --show-labels -w` 好觀察即時變化。第一種方法是**直接編輯 manifest 本身**。
- **推理 / 機制**：在 `metadata.labels` 底下加上 key-value（manifest 裡用 `:`），存檔後 `kubectl apply`——這是**完全合法的變更，Kubernetes 樂於對執行中的 Pod 套用**。
- **例子 / 應用**：
  ```yaml
  metadata:
    name: demopod
    labels:
      cool: beans        # manifest 內用冒號
  ```
  ```bash
  kubectl apply -f demopod.yaml
  # 串流視窗立刻看到 demopod 出現 label cool=beans
  ```
- **限制 / 誤區**：manifest 內語法用 `:`（YAML 風格），這與命令列的 `=` 不同（見下節），是常見混淆點。
- **關聯**：宣告式（manifest+apply）vs 命令式（`kubectl label`）是 Kubernetes 兩種操作範式的縮影。

### 12. 管理標籤（方法二）：`kubectl label`、`--overwrite`、刪除 [0:10:43–0:12:31]
**本段回答的問題**：怎麼用命令列即時加、改、刪 label？

- **概念 / 定義**：另一條路是用專門的 `kubectl label` 指令。
- **推理 / 機制與例子**：
  ```bash
  # 新增 label（命令列用 = 而非 :）
  kubectl label pod demopod awesome=sauce
  # 會「附加」到既有 label 上，不覆蓋其他

  # 若 key 已存在，直接再設值會報錯
  kubectl label pod demopod awesome=training
  # error: 'awesome' already has a value (sauce), and --overwrite is false

  # 要改值必須加 --overwrite
  kubectl label pod demopod awesome=training --overwrite
  # awesome 由 sauce 改為 training

  # 刪除 label：只給 key + 減號
  kubectl label pod demopod awesome-
  kubectl label pod demopod cool-
  # 兩個 label 都被移除，回到無 label 狀態
  ```
- **限制 / 誤區**：
  - **命令列絕對用 `=`，不能用 manifest 的 `:`**。
  - label 數量實務上**沒有上限**，但重複 key 需 `--overwrite` 才能改值。
  - 同樣的改動也能回頭在 manifest 做——兩種方式殊途同歸。
- **關聯**：熟練增刪改 label 之所以重要，是因為 Deployment、Service 這些**高度依賴 label** 的物件（下節與後續講次）。

### 13. `-L` 欄位化：把某個 key 攤成一欄 [0:12:31–0:13:37]
**本段回答的問題**：想比較「哪些 Pod 有某個 label、哪些沒有」，怎麼顯示最清楚？

- **概念 / 定義**：在 `kubectl get` 加 **`-L <key>`**（大寫 L），會**新增一欄，欄名就是那個 key**。
- **推理 / 機制**：有該 label 的 Pod 在這欄顯示其 value，沒有的顯示空白——比 `--show-labels` 把全部擠一欄乾淨得多。講者示範 key 為 `alta3`：
  ```bash
  kubectl get pods -L alta3
  # NAME       READY   STATUS    ...   ALTA3
  # demopod    1/1     Running   ...   awesome    ← 有 alta3=awesome
  # anotherpod 1/1     Running   ...              ← 空白（沒這 label）
  ```
  ```bash
  # 先給 demopod 貼上 alta3=awesome
  kubectl label pod demopod alta3=awesome
  # 再建一個沒貼此 label 的 anotherpod（也用 nginx）
  ```
- **限制 / 誤區**：`-L`（大寫，加欄位顯示）與 `-l`（小寫，selector 篩選，下節）是**兩個完全不同的旗標**，極易混淆。
- **關聯**：欄位化顯示是講者日常「label work」愛用的技巧，方便肉眼比對。

### 14. `-l` selector：從乾草堆裡撈針 [0:13:37–0:14:46]
**本段回答的問題**：上百個 Pod 裡，怎麼只挑出帶特定 label 的那些？

- **概念 / 定義**：label 還能**一次觸發（trigger）所有帶相同 label 的多個物件**。用 **`-l <key>=<value>`**（小寫 l）作為 **selector（選擇器）** 篩選。
- **推理 / 機制**：講者再建一個 `anotherpod`，也貼上 `alta3=awesome`。現在有三個「彼此毫無關聯」的 Pod。在**生產規模叢集裡會有上百個 Pod**——「如何從乾草堆裡挑出你要的那些針？」用 selector：
  ```bash
  kubectl get pods -l alta3=awesome
  # 只回傳帶 alta3=awesome 的 Pod（demopod、anotherpod），
  # 沒有此 label 的 Pod 不出現
  ```
- **例子 / 應用**：這讓你能對一個子集合批次操作（get、delete、其他動作），而不必逐一點名。
- **限制 / 誤區**：selector 是「精確條件比對」；貼錯 label 的物件會被錯誤地納入或排除（呼應第 9 節的 unintended consequences）。
- **關聯**：**如同講者反覆強調，Deployment 與 Service 正是用這種 label selector 來「嗅出（suss out）它們要找的是哪些 Pod」**——這是全課程後續控制器/服務辨識工作負載的地基。

## 🧪 實作範例（Hands-on：YAML manifest 與 kubectl）

> 以下為**教學示範**用的 manifest 與指令（非逐字稿原文引用），依本講「logs 排查 + labels 組織」兩大主線設計，可直接在測試叢集套用練習。所有欄位與指令為慣用寫法，行內以繁中 `#` 註解說明用途。

### A. 以 `metadata.labels` 標註的多容器 Pod manifest

對應第 2、9 節：一個 Pod 內兩個 busybox 容器各自產生日誌，並在 `metadata.labels` 掛上一組描述性 label，稍後用來示範 `-c`、`--all-containers` 與 selector。

```yaml
# counter-pod.yaml — 教學示範：多容器 Pod + 描述性 labels
apiVersion: v1
kind: Pod
metadata:
  name: counter
  labels:                 # metadata.labels：manifest 內用「:」(YAML 語法)
    app: web              # 應用名稱
    tier: frontend        # 分層：前端
    env: dev              # 環境：開發（稍後示範改成 prod）
    team: platform        # 負責團隊
spec:
  containers:
    - name: count         # 第一個列出的容器 → kubectl logs 的「預設容器」
      image: busybox
      command: ["sh", "-c"]
      args:
        - >               # 每 1 秒印一次日期與計數 i
          i=0; while true; do echo "$(date) count i=$i"; i=$((i+1)); sleep 1; done
    - name: count-by-three   # 第二個容器：需用 -c 指定才看得到其日誌
      image: busybox
      command: ["sh", "-c"]
      args:
        - >               # 每 3 秒印一次日期與計數 i
          i=0; while true; do echo "$(date) count-by-three i=$i"; i=$((i+1)); sleep 3; done
```

```bash
kubectl apply -f counter-pod.yaml   # 宣告式建立 Pod（見第 11 節：Kubernetes 樂於套用合法變更）
```

### B. 讀取容器日誌：`kubectl logs` 及其旗標

對應第 3、4 節。多容器 Pod 直接 `logs` 只會回傳「第一個列出的容器」，要看其它容器或即時串流需搭配旗標。

```bash
# 預設容器：不加 -c 時回傳第一個列出的容器 count 的日誌
kubectl logs counter
# 輸出開頭會提示：defaulted container "count" out of: count, count-by-three

# 指定容器：看 count-by-three（每 3 秒一筆）
kubectl logs counter -c count-by-three

# follow：即時串流新產生的日誌，需 Ctrl-C 結束
kubectl logs counter -f

# 只看最近 10 秒（相對時間窗，排查「剛剛」發生的問題很好用）
kubectl logs counter -c count-by-three --since=10s

# 一次輸出 Pod 內所有容器的日誌
kubectl logs counter --all-containers

# previous：看「上一個已崩潰的容器實例」的日誌
# 排查 CrashLoopBackOff 時的必備旗標——當前容器已重啟，錯誤線索留在前一個實例
kubectl logs counter -c count --previous
```

### C. 檢視 label：`--show-labels` 與 `-L`

對應第 10、13 節。`--show-labels` 把所有 label 擠成一欄總覽；`-L <key>`（大寫）則把單一 key 攤成獨立欄位，方便肉眼比對「哪些 Pod 有、哪些沒有」。

```bash
# 顯示每個 Pod 的所有 label（多一欄 LABELS）
kubectl get pods --show-labels

# 把 env 這個 key 攤成獨立欄位（大寫 -L 為「顯示」用途，非篩選）
kubectl get pods -L env -L tier
# NAME      READY   STATUS    ...   ENV   TIER
# counter   2/2     Running   ...   dev   frontend
```

### D. 管理 label：`kubectl label` 新增、覆寫、刪除

對應第 12 節。命令列一律用 `=`（不是 manifest 的 `:`）；改既有 key 的值須加 `--overwrite`；刪除用 `key-`（key 後接減號）。

```bash
# 新增 label（命令列用「=」）——把 env 由環境標成 prod
kubectl label pod counter env=prod --overwrite   # env 已存在，改值需 --overwrite

# 新增一個原本不存在的 label（無須 --overwrite）
kubectl label pod counter release=canary

# 刪除 label：只給 key + 減號
kubectl label pod counter release-
```

### E. label selector：`-l` 批次選取物件

對應第 14 節。`-l <key>=<value>`（小寫）是 **selector**，可用逗號串接多條件（AND），從上百個 Pod 中精準撈出子集合——這正是 Deployment / Service 辨識目標 Pod 的底層機制。

```bash
# 單一條件：撈出 app=web 的所有 Pod
kubectl get pods -l app=web

# 多條件 AND（逗號分隔）：同時符合 app=web 且 tier=frontend 才會回傳
kubectl get pods -l app=web,tier=frontend

# selector 可套用於批次操作，例如一次刪除整組符合條件的 Pod
kubectl delete pods -l app=web,tier=frontend
```

以下 manifest 片段展示 Deployment 如何用 `selector.matchLabels` 對應 Pod template 的 labels——與 C～E 節手動下的 `-l` selector 是同一套機制（預告第 8 講）：

```yaml
# 教學示範：Deployment 靠 selector.matchLabels 找到自己該管的 Pod
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:
    matchLabels:          # 控制器用這組 label 辨識「哪些 Pod 屬於我」
      app: web
      tier: frontend
  template:
    metadata:
      labels:             # Pod template 的 labels 必須被上面的 selector 覆蓋
        app: web
        tier: frontend
    spec:
      containers:
        - name: nginx
          image: nginx
```

## 🧪 例子、案例與應用

- **counter 多容器 Pod（count / count-by-three）**：一個 Pod 兩個 busybox 容器，分別每 1 秒、每 3 秒印一次日期與計數，用來示範「每容器各自日誌」「預設容器取第一個」「`-c` 指定容器」「`--since` 因節奏不同而筆數不同」等一系列日誌行為。
- **登入節點看 `/var/log/pods`**：實地展示日誌落地位置為 `/var/log/pods/<ns>_<pod>_<uid>/<container>/`，並用 `watch` 觀察 kubelet 約 45 秒後把已刪 Pod 的日誌目錄清掉——把「無常性」從抽象概念變成可觀察現象。
- **demopod（nginx）label 生命週期**：從無 label → manifest 加 `cool: beans` + apply → `kubectl label` 加 `awesome=sauce` → `--overwrite` 改 `awesome=training` → `awesome-`/`cool-` 刪除，完整走過 label 的 CRUD。
- **三個無關 Pod 用 `alta3=awesome` 串起來**：示範 label 讓「表面上毫無關聯」的物件可被 selector 一次撈出，預示 Deployment/Service 的運作。
- **生產叢集「大海撈針」**：以上百個 Pod 的規模說明為何 selector 是維運必備——沒有 label，就無法有效鎖定與批次操作工作負載。

## ⚠️ 常見誤解與反例

- **誤解**：`kubectl logs <pod>` 會顯示 Pod 裡所有容器的日誌。
  - **釐清**：多容器 Pod 預設只給「第一個列出的容器」，並印出 `defaulted container ...` 提示；要全部得加 `--all-containers`，要指定得用 `-c`。
- **誤解**：Pod 刪掉後還能之後再回頭撈它的日誌。
  - **釐清**：日誌具無常性，Pod 刪除即清理，節點上的日誌目錄約在 kubelet 下一輪清理（~60 秒）被刪；要長存必須用第三方集中式日誌方案。
- **誤解**：命令列加 label 可以用冒號，像 manifest 那樣 `key:value`。
  - **釐清**：命令列一律用 `=`（`kubectl label pod x key=value`）；`:` 只用於 manifest YAML。
- **誤解**：對已存在的 label key 重設值會直接生效。
  - **釐清**：會報錯 `key already has a value`，必須加 `--overwrite` 才能改值。
- **誤解**：`-L` 與 `-l` 是同一個東西。
  - **釐清**：`-L <key>`（大寫）是「加一欄顯示該 key 的值」；`-l <key>=<value>`（小寫）是「selector 篩選符合的物件」，用途完全不同。
- **誤解**：label 只能貼在 Pod 上。
  - **釐清**：label 可貼在任何物件上，從 Pod 一路到 Node 本身（Node label 用於排程）。
- **誤解**：label 貼錯無所謂，反正只是註記。
  - **釐清**：Deployment/Service 依 label 動作，貼錯會讓控制器/服務納入或排除錯誤的 Pod，導致嚴重非預期後果。

## 🧠 深層理解

1. **核心直覺是什麼？** 日誌 = 「容器把心事印在 stdout/stderr，Kubernetes 幫你收集」；label = 「掛在物件上的耳標，讓你能對一群物件的子集合分組與批次操作」。兩者一個管「觀察」、一個管「組織」。
2. **它解決了什麼問題？** 日誌解決「出事了怎麼查」；label 解決「幾百個 Pod 怎麼認、怎麼群管」。沒有前者無法排查，沒有後者無法規模化維運。
3. **它犧牲或忽略了什麼？** Kubernetes 原生日誌選擇了「簡單但無常」——與 Pod 生命週期綁定、不內建持久化與集中查詢，把持久性外包給第三方（EFK/Loki）。label 選擇了「自由但危險」——key/value 幾乎不設限，換來彈性，卻把「貼對」的責任丟給使用者。
4. **它和哪些概念容易混淆？** label ↔ annotation（label 供 selector 篩選、有語法限制；annotation 放任意非識別性 metadata、不可被 selector 選）；`-L` ↔ `-l`；`kubectl logs -c` 的 default container 順序 ↔ 隨機。
5. **教給初學者的比喻是什麼？** 日誌像「行車紀錄器」——事故後看它才知發生什麼，但記憶卡（Pod）拔掉/銷毀，影像就沒了，所以要另存雲端（第三方日誌）。label 像牛耳標或行李吊牌——靠它把一群東西分類、一次挑出「所有貼紅牌的行李」。
6. **現實使用的最大限制是什麼？** 日誌的無常性：任何依賴「事後翻節點日誌」的排查流程都不可靠，生產環境幾乎必須導入集中式日誌。label 則需要團隊約定一致的命名規範（如 `app`、`tier`、`env`），否則 selector 會因人而異、貼錯釀禍。

## 🕒 時間軸索引（Timeline Index）

- 0:00:00–0:00:26：日誌對故障排查的重要性；每容器各自產生 stdout/stderr 日誌
- 0:00:26–0:01:06：示範 manifest — 一 Pod 兩 busybox 容器（count 每秒、count-by-three 每三秒）
- 0:01:06–0:02:22：`kubectl logs` 基礎；多容器 Pod 的 default container（取第一個列出者）
- 0:02:22–0:03:41：旗標 `-c`、`--all-containers`、`-f`（串流）、`--since`（時間窗）
- 0:03:41–0:04:22：日誌無常性 — 刪 Pod 即刪日誌；第三方日誌方案的動機
- 0:04:22–0:06:04：登入節點看 `/var/log/pods`；目錄依 namespace/pod/container 分層
- 0:06:04–0:07:02：kubelet 約每 60 秒清理；實測 ~45 秒後日誌消失；小結 logs
- 0:07:02–0:08:07：轉入 labels；牛耳標比喻（tag 比 label 貼切）
- 0:08:07–0:09:22：label = key-value metadata；可貼任何物件；descriptive & unique；貼錯的風險
- 0:09:22–0:10:01：建無 label 的 demopod（nginx）；`--show-labels` 顯示 `<none>`
- 0:10:01–0:10:43：方法一 — 編輯 manifest（`:`）+ `kubectl apply`（cool: beans）
- 0:10:43–0:12:31：方法二 — `kubectl label`（`=`）、`--overwrite` 改值、`key-` 刪除
- 0:12:31–0:13:37：`-L <key>` 把某 label 攤成欄位；有值/空白比對
- 0:13:37–0:14:46：`-l <key>=<value>` selector 撈針；預告 Deployment/Service 用 label

## 💡 重點問答 / 自我測驗

- **Q：Kubernetes 中容器日誌的內容實際上是什麼？**
  A：該 container 的 standard out（stdout）與 standard error（stderr）輸出。
- **Q：對一個有兩個容器的 Pod 下 `kubectl logs <pod>`（不加 `-c`），會得到誰的日誌？為什麼？**
  A：manifest 中第一個列出的容器（會顯示 `defaulted container ...`）；因為它先被列出、先被建立，成為預設對象。
- **Q：如何一次看到 Pod 內所有容器的日誌？如何即時串流？如何只看最近 10 秒？**
  A：`--all-containers`；`-f`（follow）；`--since=10s`。
- **Q：為什麼說 Kubernetes 日誌具有「無常性」？實務上如何應對？**
  A：Pod 刪除會清理自己並移除所有日誌，節點目錄也會被 kubelet（約每 60 秒）清掉；應對方式是導入第三方集中式日誌方案在日誌消失前送出保存。
- **Q：容器日誌實際存在節點的哪個目錄？結構如何？**
  A：`/var/log/pods/<namespace>_<pod>_<uid>/<container>/`，root 保護，最底層才是 log 檔。
- **Q：label 的形式是什麼？可以貼在哪些物件上？**
  A：key-value pairs；可貼在任何物件，從 Pod 到 Node。
- **Q：在命令列與在 manifest 裡指定 label，語法差在哪？**
  A：命令列用 `=`（`key=value`）；manifest 用 `:`（`key: value`）。
- **Q：`kubectl label pod x foo=bar` 時 `foo` 已存在，會發生什麼？如何強制改值？**
  A：報錯 `foo already has a value`；加 `--overwrite`。
- **Q：如何刪除 Pod 上的某個 label？**
  A：`kubectl label pod x foo-`（key 後接減號）。
- **Q：`-L` 與 `-l` 差別是什麼？**
  A：`-L <key>` 加一欄顯示該 key 的值（顯示用）；`-l <key>=<value>` 是 selector，篩選符合的物件（過濾用）。
- **Q：`kubectl get pods --show-labels` 與 `-L alta3` 各適合什麼場景？**
  A：`--show-labels` 一欄看全部 label；`-L alta3` 聚焦單一 key、方便比對哪些 Pod 有/沒有該 label。
- **Q：為什麼熟練操作 label 對後續學習 Deployment、Service 很重要？**
  A：因為這些高階物件正是用 label selector 來辨識、鎖定它們要管理/導流的 Pod。
- **Q：「best labels are descriptive and unique」以及「貼錯 label」的風險說明了什麼設計取捨？**
  A：label 自由度高帶來彈性，但也把正確性責任交給使用者；貼錯會讓控制器/服務誤納或誤排 Pod，造成非預期後果，因此需要團隊命名規範。
- **Q：為什麼「cattle, not pets」的比喻適合 label？**
  A：Pod 是可替換的群體成員（牲畜），靠 label（耳標）辨識與分組，而非被當成獨一無二、需個別呵護的寵物。

## 🧩 跨領域連結

- **label selector ↔ 資料庫索引 / SQL `WHERE`**：`-l app=web` 等價於 `SELECT * FROM pods WHERE app='web'`；label 之於物件，猶如二級索引之於資料列。
- **label ↔ 集合論**：selector 定義一個子集合（subset），批次操作即對該子集合作用；多 label AND 條件 = 集合交集。
- **logs ↔ 可觀測性工程（observability）**：logs 是可觀測性三支柱（logs / metrics / traces）之一；本講只觸及 logs，metrics（Prometheus）與 traces（OpenTelemetry）是延伸。
- **日誌無常性 ↔ 資料生命週期管理**：ephemeral（短暫）儲存需搭配持久化/備份策略，對應資料工程的冷熱資料分層與保存政策。
- **耳標 metadata ↔ 畜牧/物流追蹤系統**：RFID 耳標、行李吊牌、商品條碼都是「用 key-value metadata 標記個體以便群管」的同構概念。
- **cattle-not-pets ↔ 系統設計哲學**：與無狀態服務、不可變基礎設施（immutable infrastructure）、水平擴展的設計理念一脈相承。

## 🔗 延伸學習路徑

- **下一步應學**：[[Lesson_8_Kubernetes_Deployments]]（Deployment 如何用 `selector.matchLabels` + Pod template labels 管理 ReplicaSet 與 Pod）、Service（`selector` 找 backend Pod 建 Endpoints）、annotations 與 label 的分工、`nodeSelector`/affinity（用 Node label 排程）、readiness/liveness probe 搭配 events 與 logs 的排查組合技。
- **回顧前一講**：[[Lesson_6_Kubernetes_Namespaces]]（namespace 作為物件的邏輯隔離，與 label 互補——一個是硬邊界、一個是軟分組）。
- **推薦關鍵字**：`kubectl logs -c`、`--all-containers`、`--previous`（看崩潰前一個容器實例的日誌，本講未提但排查必備）、`kubectl describe pod`、`kubectl get events`、label selector（equality-based / set-based）、`matchLabels`、`matchExpressions`、EFK、Loki、Fluent Bit。
- **相關工具 / 資源**：本 repo 的 [[gke-deploy]] skill（GKE 部署與 Pod 排查：Pending / CrashLoopBackOff / ImagePullBackOff / OOMKilled）；官方文件 `kubectl logs`、Labels and Selectors、Logging Architecture。
- **在知識地圖中的位置**：本講是「維運與組織」的地基——logs 撐起排查（troubleshooting），labels 撐起辨識與群管（organization）；再往上就是 Deployment/Service 這些「依賴 label 才能運作」的高階控制器。

> 校正說明（ASR 修正）：逐字稿為自動轉錄，本筆記已將明顯同音／誤植校正為標準術語，包括：`cube control` / `cube control logs` → `kubectl logs`；`count out of count` 的容器名還原為 `count`、`count by three` → `count-by-three`（依上下文為 manifest 容器名）；`cubelet` → kubelet；`alta three` → label key `alta3`（實際拼寫講者未明示，此處保守以 `alta3` 表示，屬示範用任意 key，不影響語意）；`demopod`、`another pod` → `anotherpod`（示範 Pod 名）；`dash c / dash f / dash l / dash dash overwrite / dash dash show labels` → `-c` / `-f` / `-l` / `--overwrite` / `--show-labels`。講者口語重複（如 "labels are no big deal. They are a series."）已整理為通順教材語句；無法可靠還原的片段（如節點目錄的完整 uid）未予杜撰，僅以結構示意。
