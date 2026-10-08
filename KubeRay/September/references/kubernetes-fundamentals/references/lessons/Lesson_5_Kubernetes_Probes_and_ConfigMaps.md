# Kubernetes FULL COURSE：Lesson 5 — Probes 與 ConfigMaps：讓應用保持健康且可配置（Kubernetes Probes and ConfigMaps - Keep Apps Healthy and Configurable）

> 來源：YouTube 影片逐字稿（SRT + 純文字，MediaTek Breeze-ASR-25 轉錄）｜https://www.youtube.com/watch?v=GjqvHl7Sj4A
> transcript_source: [[2025-08-08_GjqvHl7Sj4A_Kubernetes-FULL-COURSE-Part-5-Kubernetes-Probes-&-ConfigMaps-–-Keep-Apps-Healthy.txt]]
> 講者：Chad（CKA/CKAD 認證講師，20 年教學經驗）
> 時長：約 26:57（0:00:00–0:26:57，單一影片）
> 領域：資訊科學／雲原生（Cloud Native）／DevOps／軟體工程（容器編排 Container Orchestration）
> 難度：入門到中階（CKA / CKAD 認證基礎）
> 學習目標：理解 Kubernetes 如何以 **Probe（探針）** 主動監測容器健康、以 **liveness / readiness 兩種探針**分別「重啟不健康容器」與「把未就緒容器切離流量」；理解容器是 **stateless（無狀態）** 的、手動改進容器的設定會隨 Pod 死亡而消失，因此需要用 **ConfigMap** 把設定與容器解耦；掌握 ConfigMap 透過 **Volume → mountPath** 掛載進容器的模型，並學會 `kubectl run / port-forward / exec / cp / describe / logs`、`subPath` 與常見的 `mountPath 覆蓋目錄` 排錯。

## 📌 一句話總覽

本講回答兩個彼此相關的維運核心問題：「Kubernetes 怎麼知道我的容器還活著、能不能接流量？」以及「容器隨時會死掉、又是 stateless，那我要怎麼把設定塞進去？」前半段介紹 **Probe（探針）**——把它想成一個坐在 Pod 上、每隔幾秒就用棍子戳容器問「你還好嗎？」的看門狗（watchdog）；戳不到或回太慢就算一次 strike，累積到 `failureThreshold` 次就採取行動。行動有兩種語意：**liveness probe** 會「殺掉並重啟」失聯的容器（因為「關掉再開」是 IT 的萬年修復術），**readiness probe** 則溫柔地「把未就緒的 Pod 從流量目標中移除」，等它準備好再放流量回去。後半段用一個「示範失敗」的實驗帶出 ConfigMap：講者用 `kubectl exec` 進容器手改網頁與 `nginx.conf`，結果 Pod 一被刪除重建，改動全部消失——因為**容器是無狀態的**。解法是把設定抽離容器、放進獨立的 **ConfigMap** 物件，再以 **Volume** 掛載到 Pod、進而掛到容器的某個 `mountPath`；一份 ConfigMap 可同時掛到無數個相同的 Pod，設定只需改一處。本講在整個 Kubernetes 課程地圖中，是從「建立工作負載」跨到「維運工作負載（健康檢查 + 配置管理）」的橋樑，向前接 [[Lesson_4_Kubernetes_Deployments_and_Services]]（Deployment / Service），向後接 [[Lesson_6_Kubernetes_Persistent_Storage]]（PV / PVC 持久化儲存）與 [[gke-deploy]] 實戰部署。

## 🧭 知識地圖（Knowledge Map）

- **前置知識**：容器（container）與映像檔（image）的概念、Pod 是 Kubernetes 最小部署單位、YAML manifest 基本結構（`apiVersion / kind / metadata / spec`）、`kubectl apply / get / delete` 基本操作、HTTP GET 與 port 概念；若懂 Docker 的 volume 觀念會更快上手。
- **本集核心**：
  - **Probe 模型**：watchdog 定期探測容器 → 戳不到算 strike → 累積 `failureThreshold` 次採取行動。
  - **liveness probe**：連續失敗 → **kill / restart** 容器（重啟療法）。
  - **readiness probe**：連續失敗 → **切離流量**（從 Service 的 endpoint 移除），準備好再放回。
  - **Probe 寫在 container 層級**（不是 pod 層級），且極為 granular（可精細調整）。
  - **Probe 方法（method）**：`httpGet`（打某 port 某 path 的 GET），並非所有容器都支援此法。
  - **Probe 時間參數**：`initialDelaySeconds`、`periodSeconds`、`timeoutSeconds`、`failureThreshold`。
  - **容器 stateless**：`kubectl exec` / `cp` 的手改隨舊容器死亡而消失。
  - **ConfigMap**：把設定檔、環境變數等與容器解耦的獨立物件；只放小型純文字資料。
  - **掛載鏈**：ConfigMap →（作為）Volume → 掛到 Pod → 掛到 Container 的 `mountPath`；一份可掛多 Pod。
  - **陷阱**：`mountPath` 會**覆蓋整個既有目錄** → 需用 `subPath` 只掛單一檔案。
  - **維運指令**：`kubectl run / port-forward / exec / cp / describe / logs`。
- **後續會連到**：持久化儲存 [[Lesson_6_Kubernetes_Persistent_Storage]]（PV / PVC，處理資料庫等「大東西」）、[[Lesson_7_Kubernetes_Secrets]]（Secret，放密碼/憑證，是 ConfigMap 的加密表親）、Deployment 的滾動更新與自我修復（liveness/readiness 在其中扮演的角色）、`startupProbe`（本講未提，屬第三種探針）。
- **可跨領域連結**：控制理論／回饋控制（feedback control：探測 → 判斷 → 動作的閉環）；分散式系統的 **failure detector（故障偵測器）** 與心跳（heartbeat）機制（見 [[distsys-algebra-notes-progress]] 相關 6.824 內容）；計算機網路的 health check 與 load balancer 探活（呼應 [[Lecture_8_TCP_Congestion_Control]] 對逾時/重送的處理直覺）；十二要素應用（Twelve-Factor App）第 3 條「設定與程式碼分離」。

## 🎯 核心重點（Core Takeaways）

- **Probe 是掛在容器上的看門狗，用「定期探測 + 回應與否」判斷容器健康**：探針每隔 `periodSeconds` 對容器發一次探測，容器回「OK」就沒事；沒回應或回太慢就記一次失敗（strike），連續失敗達 `failureThreshold` 才觸發動作——注意是**連續（consecutive）**，中間成功一次就歸零。
- **liveness 與 readiness 兩種探針做的「健康檢查」完全相同，差別只在失敗後的動作**：liveness 失敗會**殺掉並重啟容器**（沿用「關掉再開」這個 IT 萬年修復術），readiness 失敗**不殺容器、只把該 Pod 從流量目標移除**，等它就緒再放流量回去。
- **liveness probe 適合「卡死但沒崩潰」的容器**：行程還在、但邏輯死鎖或無回應時，重啟往往正是解法；濫用（探測太頻繁、門檻太低）會造成健康容器被誤殺、進入無謂重啟迴圈。
- **readiness probe 保護「還在暖機、尚未就緒」的容器不被流量打到**：例如應用啟動中、還在載入資料或連 DB，此時就緒探針讓 Kubernetes 先不要把請求導過來，避免使用者打到 500。
- **Probe 加在 container 層級，而非 pod 層級**：manifest 中它是 `spec.containers[].livenessProbe` / `readinessProbe`，一個 Pod 裡不同容器可各自有自己的探針。
- **Probe 極為 granular，需要決定「用什麼方法探測」**：本講用 `httpGet`（對容器某 port 的某 endpoint 發 GET）；但並非所有容器都能被這樣探測，還有 `tcpSocket`、`exec`（跑指令看 exit code）等方法（講者提及「有很多不同做法」）。
- **四個關鍵時間參數決定探針的行為**：`initialDelaySeconds`（建立後等幾秒才第一次探測，給容器「站穩腳步」的時間）、`periodSeconds`（之後每隔幾秒探一次）、`timeoutSeconds`（一次探測給容器幾秒回應）、`failureThreshold`（連續幾次失敗才動作）。
- **探測頻率是一種 trade-off**：探得越勤（`periodSeconds` 越小）越快發現錯誤，但也更可能「抓到」偶發抖動而誤判——調參前務必讀官方文件。
- **liveness 與 readiness 的 manifest 寫法幾乎一模一樣**：把 `livenessProbe` 改成 `readinessProbe`、其餘欄位可原封不動，行為就從「重啟」變成「切流量」——所以務必分清楚你要哪一種語意。
- **容器是 stateless（無狀態）的，這是理解 ConfigMap 的關鍵前提**：用 `kubectl exec` 進容器手改的檔案、`kubectl cp` 進去的設定，都只存在於「那一個容器實例」；Pod 一被刪除重建，新容器是全新的、舊改動隨舊容器一起「死亡且消失」。
- **設定不能寫死在容器裡，必須抽離到容器之外**：既然容器會不斷生滅，`nginx.conf` 這類設定放在容器內部就會隨之消失，因此 Kubernetes 提供 **ConfigMap** 這個獨立物件來承載設定。
- **ConfigMap 是用 manifest 建立的一級資源，用來裝設定檔、環境變數等「未來可能要改」的資料**：它讓設定與容器**解耦（disengaged）**——改設定只動 ConfigMap，不用重建映像檔。
- **ConfigMap 只裝小型純文字**：`kubectl describe` 會看到內容以明文形式直接存在物件裡；資料庫這種「大東西」不放 ConfigMap，那屬於持久化儲存（persistent storage）的範疇。
- **ConfigMap 掛進容器的路徑是一條鏈：ConfigMap →（作為 Volume）→ 掛到 Pod → 掛到 Container 的 mountPath**；`volumes` 定義在 pod 層級（`spec.volumes`），`volumeMounts` 定義在 container 層級（`spec.containers[].volumeMounts`）。
- **一份 ConfigMap 可同時掛到任意多個相同的 Pod，設定只需改一處**：這是它最大的維運價值——N 個一模一樣、需要相同設定的 Pod 共用同一份 ConfigMap，改一次全體生效。
- **`mountPath` 會「覆蓋（overwrite）」整個目標目錄**：把 Volume 掛到 `/etc/nginx` 這種既有且有其他檔案的目錄，會讓原目錄內容（如 `nginx.conf`）消失，導致容器啟動失敗、進入 `CrashLoopBackOff`；解法是用 **`subPath`** 只把 ConfigMap 中的單一檔案掛到目標目錄裡，與既有檔案共存。
- **排錯的標準順序是 `describe` → `logs`**：`kubectl describe` 先看事件（可能只看到 back-off restarting，不夠具體）；`kubectl logs` 收容器的 stdout/stderr，才會看到「找不到 `nginx.conf` 檔案或目錄」這種真正的根因。
- **`kubectl run` 與 `port-forward` 是不靠 manifest 的快速測試利器**：`kubectl run` 快速建 Pod，`kubectl port-forward` 把本機任一 TCP port 接到容器內固定的 container port（如 nginx 的 80），即可用 `curl localhost:<port>` 直接驗證容器內服務。

## 🔑 關鍵字與術語表（Keywords & Glossary）

| 術語 | 原文 / 符號 | 說明 |
|---|---|---|
| 探針 | probe | 掛在容器上的看門狗（watchdog），定期探測容器是否健康 |
| 存活探針 | liveness probe | 連續探測失敗 → **殺掉並重啟**容器 |
| 就緒探針 | readiness probe | 連續探測失敗 → **把 Pod 從流量目標移除**，不殺容器 |
| 啟動探針 | startupProbe | 第三種探針（本講未提），保護慢啟動容器；供延伸 |
| 探測方法 | probe method | 探測手段：`httpGet`（本講用）、`tcpSocket`、`exec` 等 |
| HTTP GET 探測 | httpGet | 對容器某 `port` 的某 `path` 發 GET，看回應是否正常 |
| 初始延遲秒數 | initialDelaySeconds | Pod 建立後等幾秒才做第一次探測（讓容器暖機） |
| 探測週期秒數 | periodSeconds | 首次之後每隔幾秒探一次 |
| 逾時秒數 | timeoutSeconds | 一次探測給容器幾秒回應，逾時算失敗 |
| 失敗門檻 | failureThreshold | **連續**幾次探測失敗才觸發動作 |
| 連續失敗 | consecutive failures | 必須連續、中間成功一次就重新計數 |
| 精細度 | granular | Probe 可被非常精細地調參 |
| 容器 | container | 執行應用的實例；本講強調它是 stateless |
| 無狀態 | stateless | 容器不保存狀態；死亡時內部改動一併消失 |
| 短暫的 / 易逝的 | ephemeral | 形容 Pod / 容器不斷生滅、生命週期短 |
| Pod | pod | Kubernetes 最小部署單位，內含一或多個容器 |
| 設定映射 | ConfigMap | 承載設定檔/環境變數的獨立物件，與容器解耦 |
| 資料卷 | volume | 掛載到 Pod / 容器的儲存抽象；ConfigMap 以 Volume 形式被掛載 |
| 卷掛載 | volumeMounts | 在 container 層級指定把哪個 Volume 掛到哪個 `mountPath` |
| 掛載路徑 | mountPath | Volume 在容器內被掛載到的目錄；不存在會自動建立 |
| 子路徑 | subPath | 只掛 Volume/ConfigMap 中的單一檔案，避免覆蓋整個目錄 |
| 解耦 | disengaged / decoupled | 設定獨立於容器之外，改設定不動容器映像 |
| 駝峰命名 | camelCase | 如 `configMap` 的大寫 M；K8s 對大小寫敏感，易踩雷 |
| 崩潰重啟迴圈 | CrashLoopBackOff | 容器反覆啟動失敗、K8s 以退避策略不斷重試的狀態 |
| 退避重啟 | back-off restarting | `describe` 中看到的重啟退避訊息 |
| kubectl 執行進容器 | kubectl exec | 進入容器開互動式 shell（如 `sh`）或執行指令 |
| kubectl 複製 | kubectl cp | 在本機與 Pod 內容器之間複製檔案 |
| 埠轉發 | kubectl port-forward | 把本機某 TCP port 接到容器內的 container port |
| 快速建 Pod | kubectl run | 不用 manifest 直接建立 Pod（quick and dirty） |
| 檢視物件 | kubectl describe | 顯示物件詳情與事件，排錯第一步 |
| 檢視日誌 | kubectl logs | 收集容器 stdout/stderr，排錯根因常在此 |
| ConfigMap 縮寫 | cm | `kubectl` 中 configmap 的簡寫，如 `create cm` |
| 從檔案建立 | --from-file | `kubectl create cm` 由檔案內容建立 ConfigMap |
| 容器埠 | container port | 容器對外暴露的固定 port（nginx 為 80，「寫死的」） |
| tmux 分割視窗 | tmux | 終端多工，考試環境已預裝；用於同時開多個命令列 |

## 📖 詳細筆記（Detailed Notes）

### 1. 開場：Kubernetes 的一切都在服務「維持容器」，接著登場的是 Probe [0:00:00–0:00:32]
**本段回答的問題**：為什麼要有 Probe？它在 Kubernetes 全局中的定位是什麼？

- **概念 / 定義**：講者先給定位——「所有 Kubernetes 最終都是為了**維持容器（maintaining containers）**」。接著登場的 **Probe（探針）** 就是這個目標的具體工具：它是可以「疊在（put on top of）個別 Pod、進而是個別容器」之上的 **watchdog（看門狗）**，用來**監看並強制某些行為（look out for and enforce certain behavior）**。
- **推理 / 機制**：容器會出問題（卡死、未就緒、崩潰），Kubernetes 需要一種主動、自動的機制去偵測並反應，而不是等人工發現。Probe 就是這個自動化的健康監測層。
- **兩種必知類型**：`readiness`（就緒）與 `liveness`（存活）探針——「每個人都該知道的兩種」。
- **關聯**：這段是本講總綱，向前呼應「Pod / 容器是被管理的工作負載」，向後展開兩種探針的差異與 manifest 寫法。

### 2. Probe 的運作模型：拿棍子每隔幾秒戳一次容器 [0:00:32–0:01:25]
**本段回答的問題**：Probe 到底「怎麼運作」？

- **概念 / 定義**：兩種探針的運作起點都是**一個容器**。放上 Probe 後，這個探針（動畫裡畫成一隻披床單的鬼）就**不斷拿棍子戳（poking with a stick）**那個容器。
- **機制（探測迴圈）**：每隔幾秒（every couple of seconds），探針就問一次「hey，你還好嗎？（you okay?）」；容器正常就回「OMG yes」。這個問答**永遠重複下去（over and over again forever）**。
- **工程視角重述**：這是一個**週期性回饋控制迴圈（periodic feedback loop）**——探測（probe）→ 觀察回應（response / no response）→ 判斷 → 動作。頻率由後面的 `periodSeconds` 決定。
- **關聯**：這個「戳 → 回應與否」模型是理解後面所有參數（回太慢＝逾時、連續沒回＝strike）的基礎。

### 3. Liveness Probe：連續失敗就殺掉並重啟容器 [0:01:25–0:02:17]
**本段回答的問題**：liveness probe 探測失敗後會做什麼？

- **概念 / 定義**：對 **liveness probe** 而言，當容器被探測卻**完全沒有回應（no response at all）**，或**回應來得太晚（comes too late）**，探針就記一次 **strike（好球/一次失敗）**。
- **機制**：累積到**預先設定的連續 strike 次數（predetermined number of consecutive strikes）**後，探針就**殺掉這個容器（kill the container）**。這正是 liveness probe 的用途——諷刺地說，它就是拿來「殺容器」的。
- **為何殺容器有意義**：因為「**關掉再打開（turning it off and on again）**」是 IT 疑難排解的**萬年技法（time-honored technique）**；有時候「重啟容器」正是你需要的解法（例如行程死鎖、記憶體洩漏到卡住但沒真的崩潰）。
- **限制 / 誤區**：殺容器不是懲罰，是自我修復（self-healing）；但若門檻設太敏感，健康容器會被誤殺、陷入無謂重啟。
- **關聯**：與 Deployment 的自我修復能力相輔相成——容器被殺後，控制器會依 spec 重建。

### 4. Readiness Probe：溫柔家長，不殺容器只切離流量 [0:02:17–0:03:04]
**本段回答的問題**：readiness probe 和 liveness 差在哪？

- **概念 / 定義**：readiness probe **同樣**在檢查容器是否有回應（responsive），但失敗後的動作不同——它**不殺容器**。講者比喻它是「**溫柔的家長（gentle parent）**」：小容器 Timmy 還沒睡醒、還沒準備好面對這一天，大家就別去吵他、也**別把流量導給他（I don't want any traffic to go to him）**。
- **機制**：readiness 失敗時，Kubernetes 把該 Pod 從**「允許其他 Pod / 資源與它通訊」的既定設定中移除（removing that pod from any predetermined settings）**——白話說就是**把它從流量目標裡拿掉**（對應到 Service 的 endpoint 移除）。等容器準備好、探測恢復成功，再把流量放回去。
- **用途**：放上 readiness probe 可**確保容器在真正被存取之前已經就緒（ready before they are actually being accessed）**，避免請求打到還在暖機、會回錯誤的容器。
- **關聯**：readiness 與 [[Lesson_4_Kubernetes_Deployments_and_Services]] 的 Service / 負載平衡直接相關——「切離流量」就是把 Pod IP 從 Service 的 endpoints 拿掉。

### 5. Probe 寫在 Manifest 的哪裡：container 層級 [0:03:04–0:03:46]
**本段回答的問題**：Probe 在 YAML 裡長什麼樣？加在哪一層？

- **概念 / 定義**：以一個跑 `simple-service`（一個測試工具應用）的 Pod 為例，加上一個 liveness probe。**關鍵：探針加在 container 層級，不是 pod 層級**——「它不是你加到 pod 的東西，而是加到 pod 裡某個 container 的東西」。
- **機制**：因此在 manifest 中它位於 `spec.containers[].livenessProbe`。一個 Pod 內若有多個容器，各容器可各自設定自己的探針。
- **限制 / 誤區**：這是初學常見混淆點——探針的粒度是「容器」，因為健康與否是容器層級的事實。
- **關聯**：呼應第 1 節「Probe 疊在個別容器之上」。

### 6. Probe 的探測方法（method）：httpGet 打某 port 的某 endpoint [0:03:46–0:04:29]
**本段回答的問題**：探針用「什麼棍子」戳容器？

- **概念 / 定義**：Probe 極為 **granular（精細可調）**，你對它的行為有很大控制權。第一件要決定的是 **method（方法）**——也就是「探針用什麼棍子去戳容器」。
- **機制（httpGet）**：本例的 `simple-service` 是一個 **API**，能接收 **HTTP 請求**，所以探測方式是**對容器內某個特定 port 的某個 endpoint（path）發送 GET 請求**（manifest 約在第 17–19 行）。
- **限制 / 誤區**：**並非所有容器都支援這種探測方法**（不是每個容器都跑 HTTP server）。其他方法（講者說「有很多不同做法」）包含 `tcpSocket`（探 TCP 連通）與 `exec`（在容器內執行指令、看 exit code）——本講聚焦 `httpGet`。
- **關聯**：method 的選擇取決於容器暴露的介面；API/Web 服務用 `httpGet`，無 HTTP 的服務可能得用 `tcpSocket` 或 `exec`。

### 7. Probe 的四個時間參數：initialDelay / period / timeout / failureThreshold [0:04:29–0:06:24]
**本段回答的問題**：探針上面那堆秒數參數各是什麼意思？

- **`initialDelaySeconds`（初始延遲，本例 = 2）**：Pod 建立後**多久才做第一次探測**——「先讓它站穩腳步（get on its feet）幾秒，再去 tap tap 問你還好嗎」。本例等 2 秒。
- **`periodSeconds`（探測週期，本例 = 5）**：**之後每隔幾秒探一次**。時間軸：Pod 建立 → 過 2 秒（initialDelay）→ 第一次探測 → 過 5 秒 → 探測 → 再過 5 秒 → 探測……永遠重複。
- **探測頻率的 trade-off**：探得越頻繁，「越可能抓到錯誤」——這是雙面刃：早發現問題 vs 更可能被偶發抖動誤判。
- **`timeoutSeconds`（逾時，本例 = 1）**：一次探測**給容器幾秒回應**。「我 tap tap 問你還好嗎，你有 1 秒回我這個 HTTP GET，說你 OK」；逾時未回即算一次失敗。
- **`failureThreshold`（失敗門檻，本例 = 3）**：**連續（consecutive）幾次失敗**才動作——講者反覆強調 **consecutive** 很重要。對 liveness 而言，達門檻就**殺容器（不是殺 pod，是殺 container）**。
- **關聯**：這四個參數共同定義探測迴圈的時序；下一節說明同一組參數在 readiness 下語意如何改變。

### 8. Liveness 與 Readiness 寫法幾乎相同，差別只在動作 [0:06:24–0:07:21]
**本段回答的問題**：從 liveness 改成 readiness 要改多少？

- **概念 / 定義**：兩者的差異「**幾乎為零（virtually nil）**」——同一份探針設定可原封不動保留，只把類型從 `livenessProbe` 換成 `readinessProbe`，行為就變了。
- **行為對照**：同樣是「連續 3 次拿不到回應」——
  - liveness：**殺掉並重啟**容器。
  - readiness：**關閉流向該 Pod 的流量（turn off traffic）**，直到後續探測滿足條件（容器又開始回應）才**把流量放回去**。
- **限制 / 誤區**：正因寫法太像，**務必分清你要哪一種語意**——寫錯型別會造成「本想切流量卻在殺容器」或反之的嚴重誤配。
- **實務建議**：建立 Probe 時**務必讀官方文件（read the documentation）**，因為參數多且行為細膩。
- **關聯**：這也是 CKA/CKAD 常見考點——辨析兩種探針。

### 9. kubectl run 與 port-forward：不靠 manifest 快速建 Pod 並驗證 [0:07:21–0:09:35]
**本段回答的問題**：怎麼快速起一個 Pod、並從本機驗證容器內的服務？

- **鋪陳**：講者宣告接下來要做「一個**徒勞的練習（exercise in futility）**」——目的是教一個重要觀念（容器無狀態），並示範幾個好用的 `kubectl` 指令。
- **`kubectl run`**：**不用 manifest、快速髒地（quick and dirty）建 Pod**。本例建一個叫 `demo-pod`、用 `nginx` 映像的 Pod。
- **`kubectl port-forward`**：把**本機的某個 local port** 接到 **Pod 內容器的 container port**。
  - **container port 是「寫死的（written in stone）」**：nginx 容器對 HTTP 暴露在 **port 80**，不能改。
  - **local port 可任選**任何本機可用的 TCP port，本例用 **2224**。
  - 執行後這條指令會**佔用（hog up）命令列**，所以講者用 **tmux** 分割視窗（並提醒：**考試環境已預裝 tmux**）。
- **驗證**：`curl localhost:2224` → 打到透過 port-forward 連進去的 container port → 看到 nginx 的 **Welcome to nginx** HTML 歡迎頁，證明容器內服務正常。按 **Ctrl-C** 停止 port-forward 後，再 `curl localhost:2224` 就會 **fail to connect**。
- **關聯**：`port-forward` 是本機除錯（local debugging）神器，不必開 Service/Ingress 就能戳到叢集內的 Pod。

### 10. kubectl exec 進容器手動改設定 [0:09:35–0:11:19]
**本段回答的問題**：怎麼進到容器裡面手動改東西？有什麼限制？

- **`kubectl exec`**：對 `demo-pod` 開一個**互動式終端（interactive terminal）**，shell 用 `sh`（`kubectl exec -it demo-pod -- sh`）。命令列提示字元改變，代表「你人已經在 nginx 容器裡面」。
- **示範改動**：在 `/var/www` 下建目錄、用 `echo` 寫一個自訂首頁 `index.html`（內容俏皮地寫「I'm stuck in a container and I can't get out」）到 `/var/www/index.html`。
- **限制 / 誤區（重要）**：容器內**只有容器自帶的工具**。講者想用 `vim` 卻發現**容器裡根本沒裝 vim**——「用 `kubectl exec` 開 shell 時，你被限制在此刻容器內既有的工具集」。所以只能用 `echo` 這種內建手段。
- **關聯**：這種「手改」正是後面要打臉的反面示範——它改的是「這一個容器實例」。

### 11. kubectl cp：把設定檔複製進 Pod [0:11:19–0:13:25]
**本段回答的問題**：本機的設定檔怎麼弄進容器？

- **`kubectl cp`**：可在**本機檔案**與 **Pod 內容器的遠端檔案**之間**雙向複製（in and out）**。
- **示範**：把本機一份會改變 nginx 行為的 `nginx.conf` 複製進 `demo-pod`，放到 `/etc/nginx` 目錄，**覆蓋原本的那份**。（逐字稿口誤先說 `/var/www` 又改口 `/etc/nginx`。）
- **驗證改動**：進容器看 `/etc/nginx/nginx.conf`，從註解確認「這是我的自訂檔」；它會改用剛在 `/var/www` 放的自訂 index。
- **套用設定**：必須 **reload nginx** 讓改動生效。之後再 `port-forward` + `curl localhost:2224`，確實看到自訂頁面——**手改成功了**。
- **關聯**：`exec` + `cp` 是快速實驗（testing / figuring things out）的組合技，但講者強調「great in testing, **not something you'd want to do in production**」。

### 12. 容器是 stateless：Pod 一重建，手改全部消失 [0:13:25–0:14:32]
**本段回答的問題**：既然手改成功了，為什麼說它是徒勞？

- **意外**：講者「打了個噴嚏（achoo）」順手**刪掉了 Pod**。沒關係——用 `kubectl run demo-pod --image nginx` 重建，「Pod 回來了，跟原本一樣」。
- **打臉**：重開 port-forward、再 curl……**所有改動全不見了（lost all my work，none of it persisted）**。
- **根因（核心觀念）**：**容器是無狀態的（containers are stateless）**。所有改動都做在**舊容器**上；舊容器已經**死亡、消失（dead and gone）**，隨它做的改動也一併死去。新容器是全新的實例。
- **推衍出的問題**：那我們要怎麼對「像 Pod / 容器這種**易逝（ephemeral）、不斷死掉**」的東西**推送設定（push configurations）**？——這正是下一段 ConfigMap 要回答的。
- **關聯**：這是全講的樞紐——把「Probe（健康）」段落收尾，開啟「ConfigMap（配置）」段落。也直接連到 [[Lesson_6_Kubernetes_Persistent_Storage]]（無狀態 vs 持久化）。

### 13. ConfigMap 登場：把設定與容器解耦 [0:14:32–0:16:09]
**本段回答的問題**：設定不能放容器裡，那該放哪？

- **問題重述（動畫）**：在容器裡做的 `nginx.conf`，當容器與 Pod 消失時就被一併帶走——所以「設定放容器內」顯然不是解法。設定**必須放在別的地方（somewhere else）**。
- **概念 / 定義**：Kubernetes 有一種物件叫 **ConfigMap**。它是**用 manifest 建立的一級資源**（就像建 Pod 一樣）。ConfigMap 裡可以放**設定檔、環境變數，或任何你認為「未來版本的 Pod 可能需要更改」的資料**。
- **核心價值**：它讓你能以**與容器解耦（disengaged from the container）**的方式修改設定——改設定只動 ConfigMap，不必重建容器映像。
- **難易預告**：「**建立** ConfigMap 很容易；**把 ConfigMap 掛到容器**才是另一回事（something of a different story）。」有 Docker volume 經驗的人此處觀念 100% 可遷移。
- **關聯**：ConfigMap 是「設定與程式碼分離」（Twelve-Factor App）在 K8s 的落地；密碼/憑證則用其加密表親 Secret（見 [[Lesson_7_Kubernetes_Secrets]]）。

### 14. 掛載模型：ConfigMap → Volume → Pod → Container 的 mountPath [0:16:09–0:17:01]
**本段回答的問題**：ConfigMap 是怎麼一步步進到容器裡的？

- **掛載鏈（動畫講解）**：
  1. ConfigMap（裡面裝著設定檔）**先以 Volume 的形式掛載到 Pod（mounted as a volume to the pod）**。
  2. Volume 掛到 Pod 後，**再把該 Volume 掛載到容器（mount the volume to the container）**。
  3. 掛到容器時指定一個 **mount point（掛載點 / mountPath）**——容器內某個任意目錄。
- **最大的魔法（reuse）**：你可能有**很多個一模一樣、需要相同設定的 Pod**；**一份 ConfigMap 可以掛到任意多個 Pod（mount to as many pods as you want）**，所以**設定只需在一處修改（changes only need to be made in just one place）**。這是 ConfigMap 用得極頻繁的原因。
- **工程視角**：這是「單一事實來源（single source of truth）」的體現——設定集中一處，避免 N 份副本漂移。
- **關聯**：下面兩節把這條鏈拆成 manifest 的兩步：`volumes`（pod 層）與 `volumeMounts`（container 層）。

### 15. 建立與檢視 ConfigMap：kubectl create cm --from-file / describe [0:17:01–0:18:40]
**本段回答的問題**：實際怎麼建一個 ConfigMap、怎麼看裡面有什麼？

- **建立（走捷徑）**：這裡不寫 manifest，改用 `kubectl create` 指令。
  1. 先建檔：`heroes.txt`，放幾個最愛英雄——**Superman, Batman, Wonder Woman, Flash**（都是 DC 角色，後面命名會呼應）。
  2. `kubectl create configmap`（想顯得專業就用簡寫 **`cm`**）建一個叫 **`dem-heroes`** 的 ConfigMap，**從剛做的 `heroes.txt` 建立（`--from-file`）**。→ 新 ConfigMap `dem-heroes` 誕生。
- **`DATA` 欄位**：輸出顯示 `DATA 1`，代表裡面有**一筆資料**。ConfigMap **可以放多筆**嗎？可以；但除非是環境變數，**實務上多半不會**在一個 ConfigMap 裡塞很多筆。
- **檢視內容（describe）**：`kubectl describe cm dem-heroes` 會看到**設定檔內容以純文字（just as text）直接存在物件裡**。
- **限制 / 誤區**：**ConfigMap 不放大東西**——「literally 只放文字檔」。像資料庫這種大型資料屬於 **persistent storage（持久化儲存）**，是完全不同的主題（見 [[Lesson_6_Kubernetes_Persistent_Storage]]）。
- **關聯**：`--from-file` 是 imperative（命令式）建法；正式環境常改用 declarative manifest（`kind: ConfigMap`）。

### 16. 把 ConfigMap 掛進 Pod（Step 1：pod 層級的 volumes）[0:18:40–0:20:25]
**本段回答的問題**：manifest 第一步怎麼把 ConfigMap 變成 Pod 的 Volume？

- **回到先前的 Pod manifest**：先不管資源限制（resource control）那些，專注「怎麼把 ConfigMap 掛上去」。
- **Step 1 — 在 pod 層級加 `volumes`**：
  - **縮排要非常小心（mind your p's and q's）**——所以講者建議直接去 **kubernetes.io** 的 ConfigMap 頁面複製現成 manifest（**考試求生技巧**，省去縮排的痛苦）。
  - `volumes` 放在 **`spec` 底下、與 `containers` 同層**（「就在 containers 的 c 下面」），因為**這是加在 pod 層級**。
  - 可加**任意多個 volume**；每個 volume 取一個**唯一名稱**即可。本例命名 **`DC-heroes`**（呼應前面的 DC 英雄，其實可叫任何名字）。
  - volume 內容指定為一個 **`configMap`**——**注意大寫 M（camelCase）**！講者說被這個大小寫「燒到（burned）」過很多次；**K8s 對駝峰命名敏感，不小心就會咬你一口**。
  - 指定要用的 ConfigMap 名稱：**`dem-heroes`**。
- **小結**：Step 1 完成——ConfigMap 已作為 Volume 加到這個 Pod。
- **關聯**：這對應第 14 節掛載鏈的第 1 步（ConfigMap → Volume → Pod）。

### 17. 把 Volume 掛進 Container（Step 2：volumeMounts + mountPath）[0:20:25–0:22:46]
**本段回答的問題**：manifest 第二步怎麼把 Volume 掛進容器、掛到哪？

- **Step 2 — 在 container 層級加 `volumeMounts`**：
  - 位置在**容器定義內、與 `image` 同層**（「在 image 的 i 這裡，和放進 container 的其他東西一起」）。
  - `volumeMounts` 是**清單（list）**，前面的 `-`（dash）代表清單元素——**一個容器可掛多個 volume**。
  - `name`：要掛的 volume 名稱，必須**大小寫完全對上**先前的 `DC-heroes`。
  - `mountPath`：指定這個 volume**掛到 nginx 容器內的哪個目錄**。本例用 `heroes`（`/heroes`）這個**容器內原本不存在**的目錄。
- **建立與驗證**：先刪舊 Pod，再 `kubectl apply` 建新 Pod；`kubectl exec` 進去看——**多了一個 `heroes` 目錄**（證明 **mountPath 若目錄不存在會自動建立**）。進 `heroes` 目錄，裡面就是 `heroes.txt`，內容正是 Superman/Batman/…（**mountPath → volume → ConfigMap → 檔案** 這條鏈打通）。
- **持久性（相對於容器）**：只要 ConfigMap 還在，**Pod 可以整天刪了又建（all the live long day）**，`heroes.txt` 永遠都會在容器內那個目錄——**設定的生命週期脫離了容器**。
- **關聯**：對應掛載鏈第 2、3 步；也正面回答第 12 節「怎麼對易逝容器推送設定」。

### 18. 陷阱：mountPath 會覆蓋既有目錄 → CrashLoopBackOff 排錯 [0:22:46–0:25:07]
**本段回答的問題**：如果把 volume 掛到「已存在且有其他檔案」的目錄會怎樣？

- **常見錯誤情境**：想讓 `heroes.txt` 出現在一個**既有目錄**裡，例如 `nginx.conf` 所在的 `/etc/nginx`。於是把 `mountPath` 設成 `/etc/nginx`、`kubectl apply` 建 Pod。
- **症狀**：`kubectl get pods` → **出錯（womp womp）**。
- **排錯順序（重要方法論）**：
  1. **先 `kubectl describe`**：只看到「容器建好但 **backed off restart**（退避重啟）、沒能成功跑起來」——**不夠具體、幫助有限**。
  2. **再 `kubectl logs`**：收集容器的 **stdout / stderr**。這次看到真正根因——「**我試著打開 `nginx.conf`，但找不到那個檔案或目錄**」。
- **根因**：**mountPath 會覆蓋（overwrite）既有目錄**。把 volume 掛到 `/etc/nginx`，整個原目錄（含 `nginx.conf`）就被 volume 內容蓋掉，nginx 啟動時找不到設定檔而失敗 →（實務上即 `CrashLoopBackOff`）。「找不到檔案的目錄，恰好就是我們掛 volume 的目錄，這是巧合嗎？當然不是。」
- **無效的直覺**：學生常問「那把 `heroes.txt` 接在 mountPath 尾巴呢？」——那只會**建一個叫 `heroes.txt` 的目錄**，檔案跑到錯的地方，不是你要的。
- **關聯**：`describe → logs` 是通用排錯範式；也連到 [[gke-deploy]] 對 `CrashLoopBackOff` 的處理。

### 19. subPath：只掛單一檔案，與既有檔案和平共存 [0:25:07–0:26:57]
**本段回答的問題**：想把單一檔案放進「已有其他檔案的目錄」又不覆蓋，怎麼辦？

- **解法 — `subPath`**：不要把「整個 ConfigMap 的全部內容映射到整個 `/etc/nginx` 目錄」，而是用 **`subPath` 只針對 ConfigMap 裡的單一檔案**。
- **機制**：指定 ConfigMap 中的檔案 `heroes.txt`，把**這一個檔案**掛到 `/etc/nginx/heroes.txt`——即 `mountPath: /etc/nginx/heroes.txt` 搭配 `subPath: heroes.txt`。
- **結果驗證**：刪除、重建 Pod，`exec` 進去看 `/etc/nginx`——`heroes.txt` **與目錄內其他既有檔案（含 `nginx.conf`）和平共存（peacefully coexisting）**，不再整個目錄被覆蓋。
- **使用時機（收尾金句）**：**當你需要寫入一個「已有其他檔案」的目錄時，就用 `subPath`**——否則整個目錄都會被「抹平（obliterate）」。
- **限制 / 誤區**：`subPath` 掛入的檔案**不會**隨 ConfigMap 更新而自動熱更新（此為 K8s 已知行為，講者未展開，屬延伸注意事項）。
- **關聯**：`subPath` 是 volume 掛載的通用技巧，對 emptyDir、PVC 同樣適用（見 [[Lesson_6_Kubernetes_Persistent_Storage]]）。

## 🧪 例子、案例與應用

- **`simple-service` + httpGet liveness probe**：以一個能收 HTTP 的測試 API 為例，用 `httpGet` 對它的某 endpoint 週期性打 GET，示範四個時間參數如何組合成探測時序。→ 說明「health check 綁定容器暴露的介面」。
- **nginx demo-pod 的「徒勞實驗」**：`kubectl run` 建 nginx Pod → `port-forward 2224:80` → `curl` 看歡迎頁 → `exec` 進去改 `index.html`、`cp` 進 `nginx.conf`、reload → 驗證成功 → **刪 Pod 重建 → 改動全失**。→ 一個完整的「反面教材」實驗，證明**容器無狀態**、設定不可寫在容器內。
- **`dem-heroes` ConfigMap（Superman/Batman/…）**：用 `kubectl create cm --from-file heroes.txt` 建立，掛成 `DC-heroes` volume → 掛到容器 `/heroes` → 檔案在容器內出現且 Pod 重建也不消失。→ 具體演示 ConfigMap 的解耦與可重用。
- **`mountPath: /etc/nginx` 覆蓋事故**：把 volume 掛到已有 `nginx.conf` 的目錄，導致 nginx 找不到設定檔而 `CrashLoopBackOff`；用 `describe → logs` 定位、用 `subPath` 修復。→ 生產級排錯 + 掛載陷阱的實戰案例。
- **一份 ConfigMap 掛多個相同 Pod**：N 個相同 Pod 共用同一份設定，改設定只需改一處。→ 微服務多副本部署的常見模式。

## ⚠️ 常見誤解與反例

- **誤解**：liveness 和 readiness 只是名字不同，行為差不多。
  - **釐清**：健康「檢查」相同，但**失敗後動作根本不同**——liveness **殺並重啟容器**，readiness **只切離流量、不殺**。用錯型別會造成嚴重誤配（該切流量卻在殺容器）。
- **誤解**：Probe 加在 Pod 上。
  - **釐清**：Probe 加在 **container 層級**（`spec.containers[].livenessProbe`），因為健康與否是容器層級的事實。
- **誤解**：`failureThreshold` 是「累計」失敗次數。
  - **釐清**：是**連續（consecutive）**失敗次數；中間成功一次就重新計數。
- **誤解**：用 `kubectl exec` 進容器改的東西會一直存在。
  - **釐清**：容器 **stateless**，改動只在那個容器實例；Pod 重建後全部消失。這正是需要 ConfigMap 的理由。
- **誤解**：ConfigMap 可以拿來存資料庫或大檔。
  - **釐清**：ConfigMap 只放**小型純文字**（設定檔、環境變數）；大資料屬 persistent storage（PV/PVC）。
- **誤解**：把 volume 掛到既有目錄，檔案會「加進去」。
  - **釐清**：`mountPath` **覆蓋整個目標目錄**，原有檔案會被蓋掉；要與既有檔案共存必須用 **`subPath`** 只掛單一檔案。
- **誤解**：`configmap`、`configMap` 大小寫無所謂。
  - **釐清**：K8s 對 **camelCase** 敏感（`configMap` 的大寫 M）；寫錯 manifest 會失效，是常見踩雷點。
- **誤解**：`describe` 一定能看出容器為何失敗。
  - **釐清**：`describe` 常只給「back-off restarting」等籠統事件；真正根因多半要看 **`kubectl logs`** 的 stdout/stderr。

## 🧠 深層理解

1. **核心直覺是什麼？** Probe = 週期性回饋控制迴圈（探測→判斷→動作），把「人工盯著服務健康」自動化；ConfigMap = 把「易變的設定」從「易逝的容器」中抽離，讓兩者各自獨立生滅。
2. **它解決了什麼問題？** Probe 解決「容器可能卡死/未就緒，但沒人即時發現與處理」；ConfigMap 解決「stateless 容器無法保存設定、且多副本設定會漂移」。
3. **它犧牲或忽略了什麼？** Probe 增加系統複雜度與誤判風險（探測太敏感會誤殺健康容器、造成重啟風暴）；ConfigMap 只適合小型純文字、且掛載更新有其限制（`subPath` 掛入不自動熱更新），密碼類資料應改用 Secret。
4. **它和哪些概念容易混淆？** liveness vs readiness（動作不同）、Pod vs container（探針粒度）、mountPath 覆蓋 vs subPath 單檔、describe vs logs（排錯層次）、ConfigMap vs Secret vs PV/PVC（資料類型與敏感度）。
5. **教給初學者的比喻是什麼？** Probe 是坐在容器上拿棍子每隔幾秒戳一下問「你還好嗎」的看門狗鬼；liveness 是嚴厲家長（沒回應就把小孩「重開機」），readiness 是溫柔家長（小孩沒睡醒就先別讓客人來吵）。ConfigMap 是「掛在牆上的說明書」，容器換人做，說明書照舊掛著。
6. **現實使用的最大限制是什麼？** 探針參數需依應用實測調校（暖機慢的服務要加大 `initialDelaySeconds`，否則會被誤殺）；ConfigMap 改了之後，以檔案掛載的容器不一定會即時看到新值（尤其 `subPath`），常需重啟 Pod 才生效。

## 🕒 時間軸索引（Timeline Index）

- 0:00:00–0:00:32：開場——Kubernetes 皆為維持容器；Probe 是掛在容器上的 watchdog；兩種必知探針 readiness / liveness。
- 0:00:32–0:01:25：Probe 運作模型——每隔幾秒拿棍子戳容器問「你 OK 嗎」，永遠重複。
- 0:01:25–0:02:17：liveness probe——連續 strike 達門檻就殺容器（重啟療法）。
- 0:02:17–0:03:04：readiness probe——溫柔家長，不殺容器只切離流量，確保就緒才被存取。
- 0:03:04–0:03:46：Probe 寫在 container 層級（不是 pod）。
- 0:03:46–0:04:29：探測方法 method = httpGet（打某 port 的某 endpoint），非所有容器都支援。
- 0:04:29–0:06:24：時間參數 initialDelaySeconds / periodSeconds / timeoutSeconds / failureThreshold；探測頻率的 trade-off。
- 0:06:24–0:07:21：liveness 與 readiness 寫法幾乎相同，差別只在動作；務必讀文件。
- 0:07:21–0:09:35：kubectl run 快速建 Pod、port-forward（local port ↔ container port 80）、curl 驗證、tmux。
- 0:09:35–0:11:19：kubectl exec 進容器開 sh 手改 index.html；容器只有自帶工具（沒 vim）。
- 0:11:19–0:13:25：kubectl cp 複製 nginx.conf 進容器、reload、驗證手改成功。
- 0:13:25–0:14:32：刪 Pod 重建 → 改動全失 → 容器 stateless → 如何對易逝容器推送設定？
- 0:14:32–0:16:09：ConfigMap 登場——設定放容器外的獨立物件，與容器解耦。
- 0:16:09–0:17:01：掛載鏈 ConfigMap → Volume → Pod → Container mountPath；一份可掛多 Pod。
- 0:17:01–0:18:40：kubectl create cm --from-file 建 dem-heroes；describe 看純文字內容；只放小資料。
- 0:18:40–0:20:25：Step 1——pod 層級加 volumes（DC-heroes → configMap: dem-heroes；camelCase 大寫 M）。
- 0:20:25–0:22:46：Step 2——container 層級加 volumeMounts + mountPath（/heroes 自動建立）；exec 驗證、Pod 可反覆重建檔案不失。
- 0:22:46–0:25:07：陷阱——mountPath 覆蓋 /etc/nginx 既有目錄 → CrashLoopBackOff；describe→logs 排錯。
- 0:25:07–0:26:57：subPath——只掛單一檔案 heroes.txt 到 /etc/nginx，與既有檔案共存；收尾。

## 💡 重點問答 / 自我測驗

- **Q：liveness 與 readiness probe 探測失敗後各做什麼？**
  A：liveness 連續失敗達門檻會**殺掉並重啟容器**；readiness 連續失敗會**把 Pod 從流量目標移除（切離流量）**，不殺容器，等就緒再放流量回去。
- **Q：Probe 加在 Pod 還是 container？為什麼？**
  A：加在 **container** 層級（`spec.containers[].livenessProbe`）；因為健康是容器層級的事實，一個 Pod 內多容器可各自設定。
- **Q：`initialDelaySeconds`、`periodSeconds`、`timeoutSeconds`、`failureThreshold` 分別控制什麼？**
  A：建立後多久做第一次探測 / 之後每隔幾秒探一次 / 一次探測給幾秒回應 / **連續**幾次失敗才動作。
- **Q：`failureThreshold` 計的是累計還是連續失敗？**
  A：**連續（consecutive）**；中間成功一次就重新計數。
- **Q：為什麼 `kubectl exec` 手改容器的設定在 Pod 重建後會消失？**
  A：容器是 **stateless**，改動只存在於那個容器實例；Pod 重建產生全新容器，舊改動隨舊容器一起消失。
- **Q：ConfigMap 適合放什麼、不適合放什麼？**
  A：適合放**小型純文字**（設定檔、環境變數）；不適合放資料庫等大資料（那屬 PV/PVC 持久化儲存）。
- **Q：ConfigMap 掛進容器的完整鏈是什麼？在 manifest 的哪兩層？**
  A：ConfigMap →（作為 Volume）→ Pod → Container 的 mountPath；`volumes` 在 **pod 層（spec.volumes）**、`volumeMounts` 在 **container 層（spec.containers[].volumeMounts）**。
- **Q：把 volume 掛到 `/etc/nginx` 這種既有目錄會發生什麼？如何修復？**
  A：`mountPath` 會**覆蓋整個目錄**，原有 `nginx.conf` 消失、容器啟動失敗（CrashLoopBackOff）；用 **`subPath`** 只把單一檔案掛進去、與既有檔案共存。
- **Q：容器啟動失敗時，`describe` 和 `logs` 各扮演什麼角色？**
  A：先 `describe` 看事件（常只給籠統的 back-off restarting）；再 `logs` 看 stdout/stderr 找真正根因（如「找不到 nginx.conf」）。
- **Q：`kubectl port-forward` 的 local port 和 container port 有何差異？**
  A：container port 由容器決定、**寫死**（nginx=80）；local port **任選本機可用 TCP port**（示範用 2224）。
- **Q：一份 ConfigMap 能掛到幾個 Pod？帶來什麼好處？**
  A：任意多個相同 Pod；好處是**設定集中一處修改、全體生效**，避免副本設定漂移。
- **Q：為什麼講者說「探得越勤是雙面刃」？**
  A：探測越頻繁越早發現問題，但也更可能抓到偶發抖動而**誤判、誤殺健康容器**。
- **Q（應用）：一個啟動要 30 秒才就緒的服務，探針該怎麼設避免被誤殺？**
  A：加大 liveness 的 `initialDelaySeconds`（或改用 `startupProbe`）給足暖機時間；並用 readiness probe 在就緒前先不接流量。
- **Q（反例）：`subPath` 掛入的設定檔改了 ConfigMap 卻沒生效，為什麼？**
  A：以 `subPath` 掛入的檔案不會隨 ConfigMap 更新自動熱更新，通常需重啟 Pod 才會反映新值。

## 🧩 跨領域連結

- **雲原生維運 ↔ 控制理論（回饋控制）**：Probe 的「探測→判斷→動作」是典型閉環回饋系統；`periodSeconds`/`failureThreshold` 相當於取樣率與去彈跳（debounce）門檻，調參的 trade-off 與控制系統的靈敏度 vs 穩定性同構。
- **Kubernetes 健康檢查 ↔ 分散式系統 failure detector**：liveness/readiness 的心跳探測，對應分散式系統中的**故障偵測器（failure detector）**與 heartbeat；「連續失敗才判死」對應避免因網路抖動誤判節點失效（見 [[distsys-algebra-notes-progress]] 的 6.824 內容）。
- **readiness probe ↔ 計算機網路的負載平衡探活**：readiness 切離流量＝把 Pod 從 Service endpoint 移除，等同 L4/L7 load balancer 的 health check 把不健康後端移出輪替（呼應 [[Lecture_8_TCP_Congestion_Control]] 對逾時/重送的直覺）。
- **ConfigMap ↔ 軟體工程的十二要素應用（Twelve-Factor App）**：第 3 條「設定存於環境、與程式碼分離」正是 ConfigMap 的設計哲學；改設定不重建映像＝設定與部署解耦。
- **stateless 容器 ↔ 函數式編程的不可變性（immutability）**：容器如同不可變值，改動不 in-place 而是「新實例取代舊實例」；狀態/設定需外置（ConfigMap / Volume / PV）。
- **volume/mountPath ↔ 作業系統的檔案系統掛載**：K8s 的 volume mount 直接類比 Unix 的 `mount`——掛載會遮蔽（覆蓋）掛載點原有內容，`subPath` 則像 bind mount 單一檔案。

## 🔗 延伸學習路徑

- **下一步應學**：`startupProbe`（第三種探針，保護慢啟動容器）；[[Lesson_6_Kubernetes_Persistent_Storage]]（PV / PVC / StorageClass，處理「大東西」與有狀態資料）；[[Lesson_7_Kubernetes_Secrets]]（放密碼/憑證的加密表親）；ConfigMap 作為**環境變數**注入（`envFrom` / `valueFrom.configMapKeyRef`）而非只當檔案掛載。
- **推薦關鍵字**：`livenessProbe`、`readinessProbe`、`startupProbe`、`httpGet`、`tcpSocket`、`exec probe`、`initialDelaySeconds`、`failureThreshold`、`ConfigMap`、`volumeMounts`、`subPath`、`envFrom`、`CrashLoopBackOff`、`kubectl port-forward / exec / cp / logs / describe`、`Secret`、`Twelve-Factor App`。
- **相關資源**：kubernetes.io 官方文件「Configure Liveness, Readiness and Startup Probes」「ConfigMaps」「Configure a Pod to Use a ConfigMap」（講者建議直接複製官方 manifest 避免縮排踩雷）；CKA / CKAD 認證考綱的 Workloads & Scheduling、Application Configuration 章節；本 repo [[gke-deploy]] skill（在 GKE 實戰部署、排查 Pod）。
- **在知識地圖中的位置**：本講是從 [[Lesson_4_Kubernetes_Deployments_and_Services]]（如何**建立與暴露**工作負載）跨到「如何**維運**工作負載」的橋樑——健康（Probe）+ 配置（ConfigMap）+ （下一講）持久化（Storage），三者合起來構成「讓應用在生產環境長期健康運行」的基礎。

> 校正說明（ASR 修正）：本逐字稿為自動轉錄，語言被誤標為 Chinese，實際內容為英文口語，本筆記依 Kubernetes 標準術語校正並改寫為繁體中文教材。已修正的明顯同音／誤植包括：「ladeness probe」→ liveness probe；「kube control」→ `kubectl`；「dem heroes」在 K8s 命名慣例下寫作 `dem-heroes`（DNS 相容名稱）；「etsy nginx」「cngnx」→ `/etc/nginx`；「var www」→ `/var/www`；「config map」物件在 YAML 欄位為 camelCase 的 `configMap`；「port forward / port 2224 / port 80」保留原數值。逐字稿口誤「put that inside of the var www directory. No excuse me... etsy nginx directory」已依講者即時更正採 `/etc/nginx`。manifest 的具體參數值（`initialDelaySeconds: 2`、`periodSeconds: 5`、`timeoutSeconds: 1`、`failureThreshold: 3`）依講者口述之「2 秒、5 秒、1 秒、連續 3 次」對應標準欄位重建；`startupProbe` 與「subPath 不自動熱更新」為與本講直接相關之標準延伸註記，已標明屬延伸、非講者原話。無法可靠還原的片段未予杜撰。

---

## 附錄：實作範例（YAML manifest 與 kubectl 指令）

> 以下 manifest 依講者口述之欄位與參數重建，供複習與動手實作；實際欄位請以 kubernetes.io 官方文件為準。

### A. 帶 liveness probe 的 Pod（httpGet 探測，參數對應講者口述）

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: simple-service
spec:
  containers:
    - name: simple-service
      image: simple-service:latest
      ports:
        - containerPort: 8080
      livenessProbe:              # 注意：探針在 container 層級，不是 pod 層級
        httpGet:                  # method：對某 port 的某 path 發 HTTP GET
          path: /healthz
          port: 8080
        initialDelaySeconds: 2    # Pod 建立後等 2 秒才第一次探測（暖機）
        periodSeconds: 5          # 之後每 5 秒探一次
        timeoutSeconds: 1         # 一次探測給容器 1 秒回應，逾時算失敗
        failureThreshold: 3       # 連續 3 次失敗 → 殺掉並重啟「容器」
```

### B. 改成 readiness probe——寫法幾乎相同，只換型別（行為變成切流量）

```yaml
      readinessProbe:             # 僅把 livenessProbe 換成 readinessProbe
        httpGet:
          path: /healthz
          port: 8080
        initialDelaySeconds: 2
        periodSeconds: 5
        timeoutSeconds: 1
        failureThreshold: 3       # 連續 3 次失敗 → 把 Pod 從流量目標移除（不殺容器）
```

### C. 快速測試：kubectl run / port-forward / exec / cp（不靠 manifest）

```bash
# 快速建 Pod（不用 manifest）
kubectl run demo-pod --image nginx

# 把本機 2224 port 接到容器內固定的 80 port；此指令會佔用命令列（用 tmux 分割視窗）
kubectl port-forward demo-pod 2224:80

# 另一個視窗：驗證容器內 nginx 服務
curl localhost:2224          # → Welcome to nginx 歡迎頁；Ctrl-C 停止 port-forward 後會 fail to connect

# 進容器開 shell 手改（容器只有自帶工具，沒 vim）
kubectl exec -it demo-pod -- sh
#   在容器內：
#   mkdir -p /var/www
#   echo "I'm stuck in a container and I can't get out." > /var/www/index.html

# 從本機把設定檔複製進容器（雙向皆可）
kubectl cp ./nginx.conf demo-pod:/etc/nginx/nginx.conf
#   之後需 reload nginx 讓設定生效

# 注意：刪除並重建 Pod 後，上述所有手改都會消失（容器 stateless）
kubectl delete pod demo-pod
kubectl run demo-pod --image nginx     # 全新容器，改動不復存在
```

### D. 建立 ConfigMap（命令式，--from-file）

```bash
# 1) 準備一個純文字檔
printf 'Superman\nBatman\nWonder Woman\nFlash\n' > heroes.txt

# 2) 從檔案建立 ConfigMap（cm 是 configmap 的簡寫）
kubectl create configmap dem-heroes --from-file heroes.txt

# 3) 檢視：DATA 1 代表一筆資料；內容以純文字直接存在物件裡
kubectl get configmap dem-heroes
kubectl describe cm dem-heroes
```

### E. 把 ConfigMap 掛進 Pod（volumes 在 pod 層、volumeMounts 在 container 層）

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: demo-pod
spec:
  containers:
    - name: nginx
      image: nginx
      volumeMounts:               # Step 2：container 層級——把 volume 掛進容器
        - name: DC-heroes         # 必須對上下面 volumes 的名稱（大小寫敏感）
          mountPath: /heroes      # 掛載點；目錄不存在會自動建立
  volumes:                        # Step 1：pod 層級——把 ConfigMap 變成 volume
    - name: DC-heroes             # volume 名稱，唯一即可
      configMap:                  # 注意 camelCase 大寫 M！
        name: dem-heroes          # 先前建立的 ConfigMap 名稱
```

> 驗證：`kubectl exec -it demo-pod -- sh` 後，`/heroes/heroes.txt` 會出現且內容為四位英雄；即使刪除重建 Pod，只要 ConfigMap 還在，檔案永遠都在。

### F. 陷阱與修復：mountPath 覆蓋既有目錄 → 用 subPath

```yaml
      volumeMounts:
        - name: DC-heroes
          mountPath: /etc/nginx          # ✗ 錯：整個 /etc/nginx 被覆蓋，nginx.conf 消失 → CrashLoopBackOff
```

```bash
# 排錯順序：先 describe（常只看到 back-off restarting，不夠具體），再 logs（看到真正根因）
kubectl describe pod demo-pod
kubectl logs demo-pod                     # → 「找不到 nginx.conf 檔案或目錄」
```

```yaml
      volumeMounts:
        - name: DC-heroes
          mountPath: /etc/nginx/heroes.txt   # ✓ 正解：只掛「單一檔案」到既有目錄
          subPath: heroes.txt                # 指定 ConfigMap 內的單一檔案，與既有檔案共存
```
