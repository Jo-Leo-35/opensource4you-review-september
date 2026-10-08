# Kubernetes FULL COURSE 第 3 部：Kubernetes Pods 與 Namespaces 逐步實作指南（Pods & Namespaces – Step-by-Step Guide）

> 來源：YouTube 逐字稿＋SRT｜https://www.youtube.com/watch?v=7tdxlts-9qs
> 講者：Chad（CKA/CKAD 認證講師，20 年教學經驗）
> 時長：約 10:02（0:00:00–0:10:02）
> 領域：資訊科學／雲原生（Cloud Native）／DevOps／軟體工程
> 難度：入門到中階（CKA/CKAD 基礎）
> 學習目標：學會用最基本的四個 `kubectl` 動詞（get / apply / describe / delete）操作叢集中的第一個 Pod，理解「宣告式（declarative）」的核心精神，並掌握 namespace 作為叢集內邏輯隔離與存取控制邊界的用途——包括 `default` 與 `kube-system` 的差別、命令式（imperative）建立 namespace、用 `metadata.namespace` 或 `-n` 旗標指定資源歸屬，以及 ResourceQuota 對 namespace 施加資源上限的預覽。
> transcript_source: [[2025-08-08_7tdxlts-9qs_Kubernetes-FULL-COURSE-Part-3-Kubernetes-Pods-&-Namespaces-–-Step-by-Step-Guide.txt]]

## 📌 一句話總覽

本講是 Kubernetes 入門系列進入「動手操作」的第一堂實作課，回答的核心問題是：**「我要用哪些指令，才能在叢集裡把一個 Pod 生出來、看它、除錯它、刪掉它，而且不會踩到別人的地盤？」** 講者 Chad 先建立一組人人天天在用的 `kubectl` 動詞——`get`（列清單）、`apply`（把 manifest 套用到叢集）、`describe`（看細節與 events）、`delete`（刪除），並藉此帶出 Kubernetes 最重要的哲學：**宣告式（declarative）**——你不是一步步「命令」系統怎麼做，而是把「我想要的最終狀態」寫進 YAML manifest，交給叢集自己去達成並持續維持。接著他把主題切到 **namespace（命名空間）**：叢集其實是一個多人共用的環境，namespace 就是把資源在邏輯上切成互不干擾的分區——`default` 是你預設落腳的地方、`kube-system` 藏著 etcd/scheduler 這類撐住整個叢集的系統元件；namespace 的存在同時服務於「避免互相踩腳」與「存取控制（access control）」兩大目的。最後他用 **ResourceQuota** 做預告：既然是共用環境，就得有機制限制每個 namespace 能吃多少 CPU 與記憶體，避免某個 Pod 失控地把資源吃光。這一講在整體知識體系中位於「從觀念到操作」的橋樑：它把前面幾部介紹過的叢集元件（[[Lesson_2_Kubernetes_Architecture]]）落地成可敲的指令，也為後面 Deployment、Service、ConfigMap（[[Lesson_4_Kubernetes_Deployments_and_ReplicaSets]]）等更高階物件鋪好 `kubectl` 與 namespace 的地基。

## 🧭 知識地圖（Knowledge Map）

- **前置知識**：容器（container）與映像檔（image，如 nginx）的基本概念；YAML 語法（key-value、縮排、`apiVersion/kind/metadata/spec` 結構）；Kubernetes 叢集架構（control plane 的 API Server、etcd、scheduler；worker node 的 kubelet）——見 [[Lesson_2_Kubernetes_Architecture]]；命令列與文字編輯器（vi/nano）基本操作。
- **本集核心**：
  - `kubectl`（逐字稿 ASR 作 "cube control"）四大基礎動詞：`get` / `apply`（vs `create`）/ `describe` / `delete`。
  - Pod 的建立與觀察：manifest → `apply -f` → `get pods`（READY、STATUS、RESTARTS 欄位語意）→ `describe`（Events 除錯）→ `delete`。
  - **宣告式（declarative）vs 命令式（imperative）** 的差別與適用時機（含考試技巧）。
  - **namespace**：`default` 與 `kube-system`、系統整合 Pod（etcd、scheduler）、隔離與 access control 的動機。
  - 指定資源歸屬 namespace 的兩種方式：manifest 內 `metadata.namespace` vs 指令旗標 `-n <ns>`。
  - **ResourceQuota**：綁定 namespace、對整個 namespace 施加 CPU/記憶體硬上限。
- **後續會連到**：Deployment / ReplicaSet（自我修復、多副本、滾動更新）、Service / Ingress（把 Pod 對外曝露）、ConfigMap / Secret、PV / PVC（儲存）、probe（liveness/readiness）、LimitRange 與更完整的 resource requests/limits、RBAC（namespace 層級的權限控管）、context 與 kubeconfig——見 [[Lesson_4_Kubernetes_Deployments_and_ReplicaSets]]、[[Lesson_5_Kubernetes_Services_and_Networking]]、[[gke-deploy]] skill。
- **可跨領域連結**：作業系統（namespace ↔ process/資源隔離、cgroups；ResourceQuota ↔ 排程與資源配額）；資料庫（declarative ↔ SQL 宣告式查詢）；基礎設施即程式碼（Infrastructure as Code / GitOps ↔ manifest 版本控管）；多租戶系統設計（multi-tenancy ↔ namespace 邊界）。

## 🎯 核心重點（Core Takeaways）

- **`kubectl` 是操作叢集的主要 CLI，四個最基礎的動詞是 `get`、`apply`、`describe`、`delete`**：分別對應「列出物件」「把想要的狀態套用到叢集」「查看單一物件的完整細節」「刪除物件」，幾乎所有日常操作都圍繞這四個動作展開。
- **`kubectl get <資源>` 回傳的是某種資源的清單；「no resources found」不代表叢集是空的，而是「在目前這個 namespace 裡沒有」**——訊息會明確寫 `no resources found in default namespace`，這是理解 namespace 存在的第一個線索。
- **`kubectl apply -f <manifest>` 是「把 manifest 描述的狀態套用到叢集」**：若物件不存在就建立、若已存在就更新成 manifest 描述的樣子。這正是 Kubernetes **宣告式（declarative）** 的體現——你描述「要什麼」，而非「怎麼一步步做」。
- **`apply` 比 `create`更常用**：`create` 是命令式地「建立一個新物件」（若已存在會報錯），`apply` 則是冪等地讓叢集收斂到 manifest 描述的狀態，因此在管理長期演進的資源時 `apply` 更實用。
- **`kubectl get pods` 的 READY 欄位是「就緒容器數／總容器數」**：一個只放一個 nginx 容器的 Pod，剛建立時是 `0/1`（容器還在 `ContainerCreating`），起來之後變成 `1/1`（`Running`）。READY 反映的是「幾個容器真的準備好服務」，不只是「存在」。
- **STATUS 欄位描述 Pod 生命週期階段**：常見從 `ContainerCreating`（正在拉映像檔、建立容器）過渡到 `Running`；卡在某狀態或反覆變化，通常是問題的徵兆。
- **RESTARTS 欄位是關鍵健康指標；數字偏高是「大紅旗」**：大量重啟代表某個容器一直死掉又被拉起，背後幾乎一定有需要修的問題（設定錯誤、程式崩潰、探針失敗等），不能忽視。
- **`kubectl describe <資源> <名稱>` 給的是遠比 `get` 詳盡的單一物件資訊**，且輸出**最底部的 Events 區段**是除錯的第一站——資源壞掉、起不來時，先看 describe 的 Events，常能直接看到你哪裡設定錯了。
- **刪除資源有兩種等價方式**：`kubectl delete -f <manifest>`（用當初建立它的同一份檔案刪，「我能造你，就能毀你」）與 `kubectl delete <資源類型> <名稱>`（不需要 manifest，直接指名刪除）。兩者結果相同。
- **namespace（命名空間）是叢集內的邏輯分區**：`default` 本身就是一個「名叫 default 的 namespace」（不是抽象的「預設區」概念），你沒指定時資源就落在這裡；`kubectl get namespace` 可列出所有 namespace。
- **`kube-system` namespace 放的是「撐住叢集的系統整合 Pod」**（如 etcd、scheduler 等控制平面元件，依叢集建置方式而定）：把它們隔在獨立 namespace，能避免系統 Pod 和使用者的業務 Pod 混在一起互相干擾，且原則上只有管理員該去看它們。
- **namespace 的兩大核心動機是「隔離」與「存取控制（access control）」**：隔離讓不同團隊/用途的資源不互相「絆腳」；access control 讓你能限制誰能看/改哪個 namespace 的資源——後者是使用 namespace 的一個很大的理由。
- **可以「命令式（imperatively）」在命令列直接建立 namespace**：`kubectl create namespace demo` 不需要 manifest；對準備 CKA/CKAD 考試的人而言，命令式指令是快速生出物件的實用捷徑。
- **要讓資源進入指定 namespace 有兩種方式**：(1) 在 manifest 的 `metadata` 底下加 `namespace: demo`；(2) 在指令上加 `-n demo` 旗標。若都不指定，物件會落到由 context 決定的預設位置（通常是 `default`）。
- **「在錯誤 namespace 建了物件」是極常見的陷阱**：在 `demo` 建了 Pod 後，直接 `kubectl get pods`（看的是 `default`）會顯示「no resources found」，看起來像失敗，其實只是「你沒往對的地方看」——這種混淆每個人都會犯。
- **ResourceQuota 綁定在 namespace 上，替整個 namespace 設定資源消耗硬上限**（如 CPU 1 core、memory 1 gig）：因為 Kubernetes 是共用環境，必須防止任一組 Pod「失控地（hog wild）」吃光資源；quota 建立後，該 namespace 內新建的 Pod 都必須遵守這些上限。

## 🔑 關鍵字與術語表（Keywords & Glossary）

| 術語 | 原文 / 符號 | 說明 |
|---|---|---|
| kubectl | kubectl（ASR 誤作 "cube control"） | 操作 Kubernetes 叢集的主要命令列工具，透過 API Server 下達指令 |
| Pod | Pod | Kubernetes 最小可部署單元，內含一個或多個共享網路/儲存的容器 |
| 容器 | container | Pod 內實際跑應用的執行單元（本講範例為 nginx） |
| Manifest | manifest（YAML） | 描述所欲物件狀態的 YAML 檔（含 `apiVersion/kind/metadata/spec`） |
| 宣告式 | declarative | 描述「想要的最終狀態」，交由叢集收斂並持續維持；`apply` 為代表 |
| 命令式 | imperative | 直接下「做這個動作」的指令（如 `create namespace`），一次性操作 |
| `kubectl get` | get | 列出某資源類型的清單（最基礎的動詞） |
| `kubectl apply` | apply -f | 把 manifest 描述的狀態套用到叢集（不存在則建立、存在則更新） |
| `kubectl create` | create | 命令式建立新物件；物件已存在會報錯 |
| `kubectl describe` | describe | 顯示單一物件的完整細節，末尾含 Events |
| `kubectl delete` | delete | 刪除物件，可用 `-f <manifest>` 或 `<類型> <名稱>` |
| READY 欄位 | READY (n/m) | 就緒容器數／總容器數，如 `1/1` 表示 1 個容器全部就緒 |
| STATUS 欄位 | STATUS | Pod 階段狀態，如 `ContainerCreating`、`Running` |
| RESTARTS 欄位 | RESTARTS | 容器重啟次數；偏高＝異常紅旗 |
| Events | Events | `describe` 輸出末尾的事件紀錄，除錯首選 |
| namespace | namespace（`-n`） | 叢集內的邏輯分區，用於隔離與存取控制 |
| default namespace | default | 未指定時資源落腳的預設 namespace（本身即一個名叫 default 的 ns） |
| kube-system | kube-system | 存放系統整合 Pod（etcd、scheduler 等）的 namespace |
| 系統整合 Pod | system integral pods | 撐住叢集運作的核心元件 Pod |
| etcd | etcd | 叢集狀態的鍵值資料庫（control plane 元件） |
| 排程器 | scheduler | 決定 Pod 落到哪個 node 的 control plane 元件 |
| 存取控制 | access control | 限制誰能存取哪些資源；namespace 是重要的權限邊界 |
| `metadata.namespace` | metadata.namespace | manifest 內指定物件所屬 namespace 的欄位 |
| `-n` 旗標 | -n / --namespace | 指令層級指定目標 namespace |
| context | context | kubeconfig 中決定「預設叢集/namespace/使用者」的設定組合 |
| ResourceQuota | ResourceQuota | 綁定 namespace、限制其總資源消耗（CPU/記憶體）的物件 |
| 資源配額硬上限 | hard limit | quota 設定的資源消耗上限（如 CPU 1 core、memory 1 gig） |
| 共用環境 | shared environment | 叢集為多方共用，需以 quota/隔離避免資源被吃光 |
| nginx | nginx（ASR 作 "Engine X"） | 本講 Pod 範例所跑的 web server 映像檔 |

## 📖 詳細筆記（Detailed Notes）

### 1. `kubectl get`：最基礎的動詞與「no resources found」的真義 [0:00:00–0:00:44]
**本段回答的問題**：要在叢集裡動手前，第一個必學的指令是什麼？它怎麼運作？

- **概念 / 定義**：`kubectl get` 是「最基礎的（most basic）」動詞，功能是**回傳你所詢問資源類型的一份清單**。語法為 `kubectl get <資源類型>`，例如 `kubectl get pod`。
- **推理 / 機制**：講者示範 `kubectl get pod`，得到回覆 **`no resources found`**。關鍵洞察：**這不代表整個叢集沒有任何 Pod**——訊息完整版是 `no resources found in default namespace`（在 default namespace 裡找不到資源）。也就是說，`get` 預設只看你目前所在的 namespace。
- **例子 / 應用**：在乾淨的 default namespace 執行，回傳空清單；但叢集其實可能跑著很多 Pod（藏在別的 namespace，見第 8 節）。
- **限制 / 誤區**：**別把「default namespace 找不到」誤讀成「叢集是空的」**。這正是 namespace 概念的第一個伏筆——你得往對的地方看。
- **關聯**：向後連到第 3 節（用 `get pods` 觀察狀態欄位）與第 7–8 節（namespace 與 `get namespace`）。

### 2. 建立 Pod manifest 與 `apply` vs `create`：宣告式的核心 [0:00:44–0:01:42]
**本段回答的問題**：怎麼把第一個 Pod 生出來？為什麼說 Kubernetes 是「宣告式」的？

- **概念 / 定義**：先建立一份 **manifest**（YAML 檔，此處命名 `pod-manifest.yml`），貼入先前看過的 Pod 描述、存檔離開。這份檔案就是「你想要的狀態」的書面描述。
- **推理 / 機制**：套用 manifest 有兩個指令可選——`kubectl create` 與 `kubectl apply`：
  - **`kubectl apply -f pod-manifest.yml`**（較常用）：意思是「請把這個檔案位置所描述的狀態，套用到叢集」。**若該 Pod 不存在，`apply` 就會建立它**；若已存在則更新。
  - 講者強調：「我們是把 manifest 裡的內容『套用（apply）』到叢集去比對」——**這正是 Kubernetes 之所以「宣告式（declarative）」的原因**：你宣告想要什麼，叢集負責達成。
- **例子 / 應用**：執行 `apply` 後得到 `<資源> created` 的訊息，代表物件已建立。
- **限制 / 誤區**：`create` 是命令式「建立新物件」，物件已存在會報錯；`apply` 冪等（idempotent）——重複執行也安全，會收斂到 manifest 描述的樣子。日常管理長期演進的資源優先用 `apply`。
- **關聯**：宣告式思維貫穿整個 Kubernetes（Deployment、Service 皆然）；命令式的對照見第 10 節（`create namespace`）。

### 3. 觀察 Pod：`get pods` 的 READY 與 STATUS 欄位 [0:01:42–0:02:32]
**本段回答的問題**：Pod 建好後怎麼確認它起來了？`kubectl get pods` 的欄位各是什麼意思？

- **概念 / 定義**：`kubectl get pods` 列出 Pod 及其狀態欄位。剛建立時 **STATUS** 顯示 `ContainerCreating`（容器正在建立，如拉取映像檔），稍等片刻再查會變成 `Running`。
- **推理 / 機制**：重點欄位 **READY** 的格式是 `就緒容器數 / 總容器數`：
  - manifest 只放了 **一個容器**（跑 nginx），所以總數是 1。
  - 剛建立時容器還沒起來，READY 顯示 **`0/1`**（0 個就緒）。
  - 容器就緒後變成 **`1/1`**（1 個容器全部就緒、`Running`）。
- **例子 / 應用**：第一次 `get` 看到 `0/1 ContainerCreating`；給它幾秒後再 `get`，變 `1/1 Running`。
- **限制 / 誤區**：READY 反映的是「幾個容器**真的準備好服務**」，不是「幾個容器存在」。多容器 Pod 中若 READY 是 `1/2`，代表有一個容器還沒就緒，需追查。
- **關聯**：READY 的完整判斷後續會由 readiness probe 決定（見 [[Lesson_4_Kubernetes_Deployments_and_ReplicaSets]]）；STATUS 卡住的排查連到第 5 節 `describe`。

### 4. RESTARTS 欄位：重啟次數是健康的大紅旗 [0:02:32–0:02:52]
**本段回答的問題**：`get pods` 還有哪個欄位一定要盯著？它在告訴我什麼？

- **概念 / 定義**：**RESTARTS** 欄位顯示該 Pod 內容器被重啟的次數。健康剛建立的 Pod 應為 **0 restarts**。
- **推理 / 機制**：**當你看到某個 Pod 有大量 restarts，那是一面「大紅旗（big red flag）」**——代表有東西一直讓那個容器死掉，而 Kubernetes 又一直把它拉回來（重啟）。這幾乎一定是需要修的問題。
- **例子 / 應用**：常見成因（本講點到「something is causing that pod to die」，以下為工程補充）：程式啟動即崩潰、設定/環境變數錯誤、記憶體不足被 OOMKilled、liveness probe 一直失敗、相依服務連不上。這類症狀常表現為 `CrashLoopBackOff`。
- **限制 / 誤區**：0 restarts 不保證應用邏輯正確，只代表「容器沒一直死」；反之高 restarts 幾乎必然有問題，不該視而不見。
- **關聯**：下一步用 `describe` 看 Events 找根因（第 5 節）；`CrashLoopBackOff`/`ImagePullBackOff` 等排查詳見 [[gke-deploy]] skill。

### 5. `kubectl describe` 與 Events：除錯的第一站 [0:03:10–0:04:04]
**本段回答的問題**：`get` 資訊不夠時，怎麼看單一物件的全貌？資源壞了先看哪裡？

- **概念 / 定義**：`kubectl describe <資源類型> <名稱>`（如 `kubectl describe pod nginx`）**顯示遠比 `get` 詳盡的單一物件資訊**。`get` 只給簡單清單，`describe` 給「一大堆（that's a lot）」細節。
- **推理 / 機制**：`describe` 有兩個主要用途：
  1. **驗證資源是否按你的預期被建立**（double-check 設定是否如你所想）。
  2. **輸出最底部的 `Events` 區段是除錯首選**——「如果一個資源壞了、不動了，`describe` 應該是你第一個伸手去拿的工具」，因為你常能在 Events 裡直接看到「你哪裡搞砸了（goofed up）」而導致它不動。
- **例子 / 應用**：`kubectl describe pod nginx` → 捲到最下方看 Events，例如 `Failed to pull image`、`Back-off restarting failed container` 等訊息，能快速定位問題。
- **限制 / 誤區**：Events 有保留時效（預設約一小時），太舊的事件會被清掉；跨節點/歷史問題可能需搭配 `kubectl logs` 或監控系統。
- **關聯**：與第 4 節 RESTARTS 的紅旗互補——看到高 restarts 就 `describe` 找根因。

### 6. `kubectl delete`：刪除資源的兩種等價方式 [0:04:04–0:05:05]
**本段回答的問題**：Pod 用完了怎麼收掉？有哪幾種刪法？

- **概念 / 定義**：講者以「我能造你，就能毀你（I made you, I could destroy you）」帶出兩種最簡單的刪除法：
  1. **用 manifest 刪**：`kubectl delete -f pod-manifest.yml`——就像當初用 `apply -f` 建立它一樣，用同一份檔案刪掉它。
  2. **用類型＋名稱刪**：`kubectl delete pod nginx`——當你手邊沒有 manifest、或懶得去找檔案時，直接指定「刪什麼類型（pod）」＋「叫什麼名字（nginx）」。
- **推理 / 機制**：兩種方式**結果相同**，Pod 都會被刪除；差別只在你手邊有沒有那份 manifest。
- **例子 / 應用**：刪完後 `kubectl get pods` 確認已移除。至此完成了 Pod 的完整生命週期：**建立（apply）→ 檢視（get/describe）→ 刪除（delete）**。
- **限制 / 誤區**：直接對「裸 Pod（bare Pod）」`delete` 就真的沒了、不會自己回來；但若 Pod 是由 Deployment/ReplicaSet 管理，刪掉單一 Pod 會被控制器重新拉起（見 [[Lesson_4_Kubernetes_Deployments_and_ReplicaSets]]）——這是入門者常見驚訝點。
- **關聯**：`delete -f` 呼應第 2 節 `apply -f`，體現「同一份 manifest 管生也管滅」的宣告式一致性。

### 7. namespace 登場：`default` 其實是一個 namespace 的名字 [0:05:05–0:05:35]
**本段回答的問題**：前面一直出現的「default namespace」到底是什麼？

- **概念 / 定義**：**namespace（命名空間）** 是 Kubernetes 叢集內把資源邏輯切分的分區。講者回扣第 1 節的伏筆：`kubectl get pods` 回報 `no resources found in the default namespace`。
- **推理 / 機制**：關鍵澄清——用 `kubectl get namespace`（對 namespace 這個資源本身下 `get`）可以看到：**`default` 不是一個抽象的「預設區」概念，而就是一個實實在在、名字叫做 `default` 的 namespace**。你沒指定 namespace 時，資源就落在這個叫 default 的分區裡。
- **例子 / 應用**：`kubectl get namespace` 會列出叢集內所有 namespace（通常含 `default`、`kube-system`、`kube-public`、`kube-node-lease` 等）。
- **限制 / 誤區**：別把「default」誤會成某個變動的、你不知道名字的「預設地點」——它就是字面上的 `default`。
- **關聯**：接著要看的是另一個 namespace `kube-system`（第 8 節）。

### 8. `kube-system`：藏著撐住叢集的系統 Pod [0:05:35–0:06:30]
**本段回答的問題**：叢集裡明明跑了很多東西，為什麼 default 卻看不到？它們藏在哪？

- **概念 / 定義**：用 `kubectl get pods -n kube-system`（`-n` 指定 namespace）就能看到一批 Pod——這些是 **系統整合 Pod（system integral pods）**，是「撐住整個叢集（holding our cluster together）」的核心。
- **推理 / 機制**：講者回扣先前介紹過的 Kubernetes 重要元件——**etcd（叢集狀態資料庫）、scheduler（排程器）** 等：**依你叢集的建置方式，這些元件可能就是以 Pod 的形式跑在 `kube-system` 這個 namespace 裡**。（講者提到他們的教學環境設定略有不同，細節留待正式課程。）
- **例子 / 應用**：`kubectl get pods -n kube-system` 常見會看到 `etcd-*`、`kube-scheduler-*`、`kube-apiserver-*`、`kube-controller-manager-*`、`coredns-*`、CNI 網路外掛等。
- **限制 / 誤區**：**「default 看不到」不等於「不存在」**——它們只是待在 `kube-system`。呼應第 1 節：你得往對的 namespace 看。
- **關聯**：這些元件的職責詳見 [[Lesson_2_Kubernetes_Architecture]]；把系統 Pod 隔離的動機見第 9 節。

### 9. 為什麼要有 namespace：隔離與存取控制 [0:06:30–0:06:55]
**本段回答的問題**：把系統 Pod 放進 `kube-system` 到底有什麼好處？namespace 的價值是什麼？

- **概念 / 定義**：namespace 的存在服務兩大目的：
  1. **隔離、避免互相絆腳**：系統 Pod 放在 `kube-system`，就不會在你建立「業務相關 Pod（business related pods）」時「礙手礙腳（underfoot）」——兩類資源在邏輯上分開，各看各的。
  2. **存取控制（access control）**：原則上除了管理員（admin），沒人該去看 `kube-system` 那些 Pod；講者強調 **access control 是想使用 namespace 的一個「非常非常大」的理由**。
- **推理 / 機制**：把資源依用途/團隊切進不同 namespace，就能：讓 `get`/清單不被無關資源淹沒；並在 namespace 邊界上套用權限規則（後續的 RBAC）。
- **例子 / 應用**：team-a / team-b 各自的 namespace；prod / staging / dev 分離；系統元件獨立於 `kube-system`。
- **限制 / 誤區**：namespace 是**邏輯**隔離，不是強安全邊界——同叢集不同 namespace 的 Pod 網路預設仍可互通（需 NetworkPolicy 才能限制）；真正的權限限制要靠 RBAC 綁在 namespace 上。
- **關聯**：access control 連到 RBAC；資源隔離的「量」的層面連到第 13 節 ResourceQuota。

### 10. 命令式建立 namespace 與 CKA/CKAD 考試技巧 [0:06:55–0:07:24]
**本段回答的問題**：怎麼開一個新的 namespace？考試時有沒有更快的做法？

- **概念 / 定義**：建立新 namespace 不難。講者選擇用 **命令式（imperatively）** 的方式——**直接在命令列下指令、完全不寫 manifest**：`kubectl create namespace demo`。
- **推理 / 機制**：**命令式 vs 宣告式** 的取捨：
  - 宣告式（`apply -f` 一份 YAML）適合需要版本控管、長期維護的資源。
  - 命令式（`create namespace`、`kubectl run` 等）**快、省事**，適合一次性、臨時、或考試情境。
- **例子 / 應用**：講者明講——**若你準備考 CKA/CKAD，命令式指令是「超快又簡單」生出特定物件的方式**；他這次 demo 就用 `kubectl create namespace demo` 開了一個叫 `demo` 的 namespace。
- **限制 / 誤區**：命令式方便但不留「意圖檔」在版本庫，團隊協作/重現環境時仍建議把最終狀態寫成 manifest（可用 `--dry-run=client -o yaml` 由命令式產生 YAML 骨架）。
- **關聯**：這與第 2 節「宣告式 apply」形成完整對照；產生的 `demo` namespace 用於第 11–13 節的示範。

### 11. 讓 Pod 進入指定 namespace（方式一）：`metadata.namespace` [0:07:24–0:08:03]
**本段回答的問題**：物件預設會落在哪？怎麼強制它去我要的 namespace？

- **概念 / 定義**：關於 manifest 有個要點——**建立物件時若你沒指定它該去哪，它會落到一個由 context 決定的預設位置**（context 是什麼留待後續，通常即 `default`）。
- **推理 / 機制**：要強制 Pod 或其他物件進入特定 namespace，方式一是**在 manifest 的 `metadata` 底下加一行 `namespace: demo`**。講者回到先前那份 pod manifest，加上這行後再 `apply`。
- **例子 / 應用**：
  ```yaml
  metadata:
    name: nginx
    namespace: demo      # ← 強制這個 Pod 建到 demo namespace
  ```
  執行 `kubectl apply -f pod-manifest.yml` → 回報「pod created」。
- **限制 / 誤區**：把 namespace 寫死在 manifest 裡，等於把「這份 YAML 只屬於 demo」綁死；若想同一份 manifest 部署到多個 namespace，反而用指令旗標（第 14 節）更靈活。
- **關聯**：建立後看不到 Pod 的陷阱見第 12 節；另一種指定方式（`-n` 旗標）見第 14 節。

### 12. namespace 最常見的陷阱：`get pods` 看不到剛建的 Pod [0:08:03–0:08:37]
**本段回答的問題**：明明 apply 成功了，為什麼 `get pods` 又說「no resources found」？我做錯了嗎？

- **概念 / 定義**：把 Pod 建到 `demo` 後，若直接執行 `kubectl get pods`（沒加 `-n`，看的是 `default`），會再次得到 **`no resources found`**——看起來像失敗。
- **推理 / 機制**：講者自問「我搞砸了嗎？」答案是**沒有**：Pod 好好地在 `demo` namespace 裡，只是 `kubectl get pods` 預設看 `default`，所以看不到。要看得加 `-n demo`：`kubectl get pods -n demo`。
- **例子 / 應用**：`kubectl get pods` → 空；`kubectl get pods -n demo` → 看到剛建的 nginx。
- **限制 / 誤區**：**「在錯誤的 namespace 建立物件」是每個人都會犯的常見錯誤**，且造成的混淆很折磨人。講者的忠告：**forewarned is forearmed（事先知道就能事先防備）**。實務上可用 `kubectl config set-context --current --namespace=demo` 切換預設 namespace，或用 `kubectl get pods -A`（所有 namespace）避免漏看。
- **關聯**：這個陷阱正是第 1、7、8 節「no resources found ≠ 空」的反覆主題；解法連到 context 設定。

### 13. ResourceQuota 預覽：共用環境下的資源硬上限 [0:08:37–0:09:23]
**本段回答的問題**：既然叢集是大家共用的，怎麼防止某些 Pod 把資源吃光？

- **概念 / 定義**：講者以此作為「稍後 resource control」章節的預告。核心前提：**Kubernetes 是一個共用環境（shared environment）**，你得確保建立資源時不會「佔用超過你該得的份額」，也要防止 Pod「失控地（hog wild）」吃掉太多資源。
- **推理 / 機制**：**ResourceQuota** 是一種**綁定在 namespace 上、替整個 namespace 設定規則**的物件——它宣告「這個 namespace 裡所有東西加起來，最多能消耗多少資源」的**硬上限（hard limit）**。範例上限：**CPU 1 core、memory 1 gig**。
- **例子 / 應用**：
  ```yaml
  apiVersion: v1
  kind: ResourceQuota
  metadata:
    name: demo-quota
  spec:
    hard:
      cpu: "1"          # 整個 namespace 最多 1 core
      memory: 1Gi       # 整個 namespace 最多 1 GiB
  ```
- **限制 / 誤區**：ResourceQuota 一旦生效，該 namespace 內的 Pod 通常**必須自行宣告 resource requests/limits**，否則可能被拒絕建立（本講未展開，屬後續 resource control 主題）。quota 是「namespace 總量」層級，單一 Pod 的上下限另由 LimitRange/容器 limits 控制。
- **關聯**：向後連到 resource requests/limits、LimitRange、HPA 自動擴縮；隔離的「量」對照第 9 節隔離的「邏輯」。

### 14. 指定資源歸屬的第二種方式：`-n` 旗標，與 `describe` 確認 [0:09:23–0:10:02]
**本段回答的問題**：除了寫進 manifest，還能怎麼指定資源該建到哪個 namespace？

- **概念 / 定義**：講者藉建立 ResourceQuota 的機會，示範**指定資源歸屬 namespace 的第二種方式**：不寫在 manifest 的 `metadata` 裡，而是**在指令上加 `-n demo` 旗標**。
- **推理 / 機制**：兩種方式對比——
  - **方式一（第 11 節）**：manifest 內 `metadata.namespace: demo`（把歸屬綁進檔案）。
  - **方式二（本節）**：指令加 `-n demo`（把歸屬留在執行當下決定，manifest 保持中立）。
  - 執行 `kubectl apply -f resource-quota.yml -n demo` → 回報 quota 已套用（applied）。
- **例子 / 應用**：套用後用 **`kubectl describe resourcequota -n demo`**（呼應第 5 節）確認 quota 生效；此後**在 `demo` 建立的任何 Pod 都必須遵守這些資源消耗規則**。
- **限制 / 誤區**：若 manifest 內已寫 `metadata.namespace`，又在指令加了不同的 `-n`，兩者衝突時 kubectl 會報錯——不要同時給出互相矛盾的歸屬。方式二讓同一份 manifest 可重用於多個 namespace，較靈活。
- **關聯**：`describe` 確認呼應第 5 節；「namespace 有多重要」的總結呼應第 9、13 節，收束整堂課。

## 🧪 實作範例（Hands-on：YAML manifest 與 kubectl）

> 本節為**教學示範**（非逐字稿逐字引用），把本講第 1–14 節的概念串成一條可實際敲進終端機的操作流程。示範採用 `dev` 這個 namespace（等同講者 demo 中的 `demo`），涵蓋：命令式建立 namespace（第 10 節）、宣告式 Namespace manifest（第 2、7 節）、把 Pod 指定到 namespace 的兩種方式（第 11、14 節）、多容器 Pod（第 3 節 READY 語意）、以及 `get / describe / delete` 的完整生命週期（第 3–6 節）。所有 YAML 皆語法正確、可直接 `kubectl apply`。

### A. 建立 namespace：命令式 vs 宣告式（第 7、10 節）

先用**命令式（imperative）**一行建立——最快、考試好用（第 10 節）：

```bash
# 命令式：不寫 manifest，直接生出一個名叫 dev 的 namespace
kubectl create namespace dev

# 列出所有 namespace，確認 dev 已建立（default 只是「字面上叫 default」的一個 namespace）
kubectl get namespace
```

同一件事也能用**宣告式（declarative）**的 Namespace manifest 表達，適合納入版控／GitOps（第 2 節）：

```yaml
# namespace-dev.yml —— 宣告式定義一個 namespace，效果等同上面的 create namespace dev
apiVersion: v1
kind: Namespace           # 這份 manifest 描述的物件類型是 Namespace 本身
metadata:
  name: dev               # namespace 的名字
  labels:
    environment: dev      # 慣用做法：用 label 標註用途，方便後續選取與治理
```

```bash
# 把上面的宣告套用到叢集：不存在則建立、已存在則更新（冪等，第 2 節）
kubectl apply -f namespace-dev.yml
```

### B. 把 Pod 部署到指定 namespace（方式一：`metadata.namespace`，第 11 節）

在 Pod manifest 的 `metadata` 底下寫死 `namespace: dev`，這個 Pod 就一定建到 `dev`：

```yaml
# pod-nginx-dev.yml —— 單容器 Pod，透過 metadata.namespace 綁定到 dev（第 11 節方式一）
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  namespace: dev          # ← 方式一：把歸屬綁進 manifest，這份檔案只屬於 dev
  labels:
    app: nginx
spec:
  containers:
    - name: nginx
      image: nginx:1.27   # 本講範例映像檔（逐字稿口語 "Engine X" 即 nginx）
      ports:
        - containerPort: 80
```

```bash
# 套用後 kubectl 會回報 pod/nginx created
kubectl apply -f pod-nginx-dev.yml

# 常見陷阱（第 12 節）：不加 -n 看的是 default，會顯示 no resources found
kubectl get pods                 # → No resources found in default namespace.

# 往對的地方看：加 -n dev 才看得到剛建的 Pod（觀察 READY 0/1→1/1、STATUS、RESTARTS）
kubectl get pods -n dev

# 一次看「所有」namespace，避免漏看（-A 等同 --all-namespaces）
kubectl get pods --all-namespaces
```

### C. 多容器 Pod：READY 欄位為何是 `n/m`（第 3 節）

一個 Pod 可放多個共享網路與儲存的容器；此時 `kubectl get pods` 的 READY 會是「就緒容器數／總容器數」，例如 `2/2` 代表兩個容器都就緒（第 3 節）。下例為一個 web 容器搭配一個 sidecar log 容器：

```yaml
# pod-multi-container.yml —— 多容器 Pod：主容器 nginx + sidecar，共享同一 Pod 網路與 emptyDir 卷
apiVersion: v1
kind: Pod
metadata:
  name: web-with-sidecar
  namespace: dev
spec:
  volumes:
    - name: shared-logs         # 兩個容器共用的暫存卷，示範 Pod 內容器如何共享儲存
      emptyDir: {}
  containers:
    - name: web                 # 主容器：對外服務的 nginx
      image: nginx:1.27
      ports:
        - containerPort: 80
      volumeMounts:
        - name: shared-logs
          mountPath: /var/log/nginx
    - name: log-reader          # sidecar：持續讀取共享卷內的 log（教學用途）
      image: busybox:1.36
      command: ["/bin/sh", "-c", "tail -F /logs/access.log"]  # 慣用的 sidecar tail 模式
      volumeMounts:
        - name: shared-logs
          mountPath: /logs
```

```bash
# 這個 Pod 有兩個容器，兩者都就緒後 READY 會顯示 2/2
kubectl apply -f pod-multi-container.yml
kubectl get pods -n dev          # 觀察 READY 由 0/2 → 2/2
```

### D. 命令式快速起一個 Pod：`kubectl run`（第 10 節考試技巧）

除了寫 manifest，也能用命令式 `kubectl run` 直接生出 Pod——CKA/CKAD 考試搶時間的利器（第 10 節）：

```bash
# 命令式在 dev 直接跑一個 nginx Pod，不需要任何 YAML
kubectl run nginx-quick --image=nginx:1.27 -n dev

# 進階：用 --dry-run 由命令式「反產生」YAML 骨架，再存檔改成宣告式（第 10 節誤區補充）
kubectl run nginx-quick --image=nginx:1.27 -n dev --dry-run=client -o yaml > pod-generated.yml
```

### E. 觀察、除錯與清理：完整生命週期（第 3–6 節）

```bash
# 看細節與 Events：資源壞掉、卡住時的除錯首選（第 5 節），Events 在輸出最底部
kubectl describe pod nginx -n dev

# 刪除方式一：用當初建立它的同一份 manifest 刪（「我能造你，就能毀你」，第 6 節）
kubectl delete -f pod-nginx-dev.yml

# 刪除方式二：不需要 manifest，直接指定 類型 + 名稱 刪（結果相同，第 6 節）
kubectl delete pod nginx -n dev

# 確認已移除（在對的 namespace 查）
kubectl get pods -n dev
```

## 🧪 例子、案例與應用

- **完整 Pod manifest（nginx，本講範例的工程重建）**：對照第 2–3 節的「一個容器、跑 nginx」。
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: nginx
    namespace: demo          # 第 11 節：方式一，寫進 manifest
    labels:
      app: nginx
  spec:
    containers:
      - name: nginx
        image: nginx:1.27
        ports:
          - containerPort: 80
  ```
- **Pod 完整生命週期一條龍（第 2–6 節）**：
  ```bash
  kubectl apply -f pod-manifest.yml            # 建立（宣告式）
  kubectl get pods                             # 看 READY / STATUS / RESTARTS
  kubectl get pods -w                          # -w 持續監看狀態變化（0/1→1/1）
  kubectl describe pod nginx                   # 看細節與 Events（除錯首選）
  kubectl delete -f pod-manifest.yml           # 用 manifest 刪
  kubectl delete pod nginx                     # 或用 類型+名稱 刪
  ```
- **namespace 操作全集（第 7–14 節）**：
  ```bash
  kubectl get namespace                        # 列出所有 namespace（default 只是一個名字）
  kubectl get pods -n kube-system              # 看撐住叢集的系統 Pod（etcd/scheduler…）
  kubectl create namespace demo                # 命令式建立 namespace（考試好用）
  kubectl get pods                             # 看 default → no resources found
  kubectl get pods -n demo                     # 往對的地方看 → 看到 nginx
  kubectl get pods -A                          # 一次看所有 namespace，避免漏看
  ```
- **ResourceQuota 套用與確認（第 13–14 節）**：
  ```bash
  kubectl apply -f resource-quota.yml -n demo  # 方式二：用 -n 旗標指定歸屬
  kubectl describe resourcequota -n demo       # 確認 quota 生效與用量
  ```
- **RESTARTS 紅旗的實戰情境（第 4 節）**：某 Pod `get pods` 顯示 `0/1  CrashLoopBackOff  7 (2m ago)`——7 次重啟即紅旗，`kubectl describe pod <name>` 看 Events，常見 `Back-off restarting failed container` 或映像檔/設定錯誤。

## ⚠️ 常見誤解與反例

- **誤解**：`no resources found` 代表叢集裡沒有任何該類資源。
  - **釐清**：它只代表「**目前這個 namespace** 裡沒有」。訊息會寫明 `in default namespace`；換 `-n kube-system` 或 `-A` 就看得到（第 1、8、12 節）。
- **誤解**：`default` 是某個抽象、會變動的「預設區」。
  - **釐清**：`default` 就是一個**字面上名字叫 default** 的 namespace，`kubectl get namespace` 看得到它（第 7 節）。
- **誤解**：`apply` 和 `create` 一樣，可以互換。
  - **釐清**：`create` 命令式建立，物件已存在會報錯；`apply` 宣告式收斂，不存在則建、存在則更新，冪等（第 2 節）。
- **誤解**：READY `1/1` 中的兩個數字是「重啟成功/失敗」之類。
  - **釐清**：是「**就緒容器數 / Pod 內總容器數**」。單容器 Pod 起來後是 `1/1`；`0/1` 表示唯一容器還沒就緒（第 3 節）。
- **誤解**：RESTARTS 有數字很正常，不用管。
  - **釐清**：健康 Pod 應為 0；**數字偏高是大紅旗**，代表容器一直死掉被重拉，需追根究柢（第 4 節）。
- **誤解**：namespace 提供的是像 VM 那樣的強安全/網路隔離。
  - **釐清**：namespace 是**邏輯**分區，主要服務於組織與 access control；不同 namespace 的 Pod 網路預設仍互通，需 NetworkPolicy 才隔離網路，需 RBAC 才隔離權限（第 9 節）。
- **誤解**：把 Pod 建到 `demo` 後 `get pods` 看不到＝建立失敗。
  - **釐清**：Pod 在 `demo` 好好的，只是你在看 `default`。加 `-n demo` 即可——這是「每個人都會犯」的經典陷阱（第 12 節）。
- **誤解**：ResourceQuota 是限制單一 Pod 的用量。
  - **釐清**：ResourceQuota 限制的是**整個 namespace 的總用量**（硬上限）；單 Pod/容器的上下限由 limits/LimitRange 負責（第 13 節）。

## 🧠 深層理解

1. **核心直覺是什麼？** Kubernetes 的操作可濃縮成「用 `kubectl` 對某個 **namespace** 裡的物件做 CRUD」：`apply` 描述你要什麼（宣告式），`get`/`describe` 看現況，`delete` 收掉；而 namespace 決定「這些動作作用在叢集的哪個分區」。
2. **它解決了什麼問題？** (a) 宣告式讓你不必寫「怎麼一步步達成」的腳本，只描述終態，叢集自己收斂與維持；(b) namespace 解決多人/多用途共用一個叢集時的「組織、避免互相絆腳、權限控管、資源配額」問題。
3. **它犧牲或忽略了什麼？** 宣告式的抽象讓你看不到底層「怎麼做」，除錯時要靠 `describe`/Events/logs 反推；namespace 是邏輯隔離、非強隔離，安全性仍需 RBAC + NetworkPolicy 補足，且「預設看 default」的設計是新手混淆的主因。
4. **它和哪些概念容易混淆？** `apply` vs `create`（宣告 vs 命令）；READY vs STATUS（就緒容器數 vs 生命週期階段）；namespace 邏輯隔離 vs OS/VM 實體隔離；ResourceQuota（namespace 總量）vs limits/requests（單容器）。
5. **教給初學者的比喻是什麼？** 叢集像一棟共用辦公大樓；namespace 是各團隊的樓層/隔間（`kube-system` 是機房，只有管理員進得去）；manifest 是「我想要的房間佈置圖」，`apply` 是把圖交給物業去照做並維持；ResourceQuota 是「這個隔間的用電/用水總上限」。
6. **現實使用的最大限制是什麼？** 對入門者而言最大的坑是 **namespace 情境感（context）**——忘了自己在哪個 namespace、把東西建錯地方、或以為叢集是空的。實務上務必善用 `-A`、`-n`、切換 context 的習慣，並讓 CI/GitOps 明確寫死目標 namespace。

## 🕒 時間軸索引（Timeline Index）

- 0:00:00–0:00:44：`kubectl get` 基礎；`no resources found in default namespace` 的真義（第 1 節）
- 0:00:44–0:01:42：建立 pod manifest；`apply` vs `create` 與宣告式（declarative）（第 2 節）
- 0:01:42–0:02:32：`get pods` 的 READY（`0/1`→`1/1`）與 STATUS（`ContainerCreating`→`Running`）（第 3 節）
- 0:02:32–0:02:52：RESTARTS 欄位——重啟次數偏高是大紅旗（第 4 節）
- 0:03:10–0:04:04：`kubectl describe` 與底部 Events 區段，除錯首選（第 5 節）
- 0:04:04–0:05:05：`kubectl delete` 的兩種方式（`-f` vs 類型+名稱）（第 6 節）
- 0:05:05–0:05:35：namespace 登場；`default` 就是一個 namespace 的名字（第 7 節）
- 0:05:35–0:06:30：`kube-system` 與系統整合 Pod（etcd、scheduler）（第 8 節）
- 0:06:30–0:06:55：namespace 的動機——隔離與 access control（第 9 節）
- 0:06:55–0:07:24：命令式建立 namespace；CKA/CKAD 考試技巧（第 10 節）
- 0:07:24–0:08:03：用 `metadata.namespace` 指定 Pod 歸屬（方式一）（第 11 節）
- 0:08:03–0:08:37：常見陷阱——建到 demo 卻在 default 找不到（第 12 節）
- 0:08:37–0:09:23：ResourceQuota 預覽——共用環境的資源硬上限（第 13 節）
- 0:09:23–0:10:02：用 `-n` 旗標指定歸屬（方式二）＋ `describe` 確認（第 14 節）

## 💡 重點問答 / 自我測驗

- **Q：`kubectl get pod` 回傳 `no resources found`，能否斷定叢集裡沒有任何 Pod？**
  A：不能。它只表示「目前的（default）namespace 沒有 Pod」。用 `kubectl get pods -n kube-system` 或 `kubectl get pods -A` 通常會看到很多 Pod。
- **Q：`kubectl apply` 與 `kubectl create` 有何差別？為何 `apply` 更常用？**
  A：`create` 命令式建立新物件，已存在會報錯；`apply` 宣告式地把 manifest 描述的狀態套用到叢集（不存在則建、存在則更新），冪等且體現 declarative 精神，故日常管理長期資源多用 `apply`。
- **Q：`kubectl get pods` 顯示 `READY 0/1`，這代表什麼？**
  A：Pod 內有 1 個容器，目前有 0 個就緒（可能還在 `ContainerCreating`）。就緒後會變 `1/1`。READY 是「就緒容器數／總容器數」。
- **Q：看到一個 Pod 有很多 RESTARTS，你會怎麼判讀與處置？**
  A：這是異常紅旗，代表容器一直死掉又被重啟。先 `kubectl describe pod <name>` 看 Events，再看 `kubectl logs`，追查是設定錯誤、崩潰、OOM 還是探針失敗（常見 `CrashLoopBackOff`）。
- **Q：資源壞掉、起不來時，第一個該用的除錯工具是什麼？為什麼？**
  A：`kubectl describe <類型> <名稱>`，特別看輸出底部的 **Events** 區段，常能直接看到出錯原因。
- **Q：刪除一個 Pod 有哪兩種等價方式？**
  A：`kubectl delete -f <manifest>`（用建立它的檔案刪）或 `kubectl delete pod <名稱>`（用類型＋名稱刪），結果相同。
- **Q：`default` namespace 是什麼？**
  A：它是一個字面上名字就叫 `default` 的 namespace，是你未指定 namespace 時資源預設落腳的分區，可用 `kubectl get namespace` 看到。
- **Q：`kube-system` 裡放的是什麼？為什麼要獨立成一個 namespace？**
  A：放系統整合 Pod（如 etcd、scheduler 等撐住叢集的元件）。獨立成 namespace 是為了不與業務 Pod 互相干擾，且便於 access control（只有 admin 該碰）。
- **Q：使用 namespace 的兩大核心動機是什麼？**
  A：隔離（避免不同用途/團隊的資源互相絆腳）與存取控制（access control，在 namespace 邊界上限制誰能存取）。
- **Q：把物件建到指定 namespace 有哪兩種方式？各適合何時用？**
  A：(1) manifest 內 `metadata.namespace: demo`——歸屬綁進檔案；(2) 指令加 `-n demo`——歸屬在執行時決定，同一份 manifest 可重用於多 namespace。兩者衝突會報錯。
- **Q：為何在 `demo` 建了 Pod，`kubectl get pods` 卻說找不到？**
  A：因為 `get pods` 預設看 `default`，Pod 其實在 `demo`。加 `-n demo` 即可看到。這是最常見的 namespace 陷阱。
- **Q：ResourceQuota 是什麼？作用在什麼層級？**
  A：綁定在 namespace 上、對「整個 namespace 的資源消耗總量」設硬上限（如 CPU 1 core、memory 1 gig）的物件，用來防止共用環境中資源被吃光。
- **Q：為什麼說 Kubernetes 是「宣告式」的？**
  A：因為你用 manifest 描述「想要的最終狀態」並 `apply`，由叢集負責達成並持續維持，而非你逐步命令它怎麼做。
- **Q：準備 CKA/CKAD 時，為什麼命令式指令很有用？**
  A：像 `kubectl create namespace demo` 這類命令式指令能超快生出物件，在有時間壓力的考試中比手寫完整 YAML 更有效率。

## 🧩 跨領域連結

- **雲原生 ↔ 作業系統**：namespace/ResourceQuota 的隔離與配額，概念上對應 OS 的 process 隔離、Linux namespaces 與 cgroups 的資源限制——都是「在共用硬體上安全地多方共存」。
- **宣告式 ↔ 資料庫/函數式**：`apply` 的「描述終態、系統收斂」與 SQL 的宣告式查詢、函數式程式的「描述而非步驟」同源；也與 Terraform/GitOps 的 Infrastructure as Code 一脈相承。
- **namespace ↔ 多租戶系統設計**：把單一叢集切成邏輯分區，正是 SaaS 多租戶（multi-tenancy）中「軟隔離 + 配額 + 權限」的縮影。
- **RESTARTS/Events 除錯 ↔ 可觀測性（Observability）**：READY/RESTARTS/Events 是最基本的 metrics 與 event log，串到後續 Prometheus/Grafana、logging pipeline 的監控體系。
- **access control ↔ 資訊安全**：namespace 作為 RBAC 的授權邊界，體現最小權限原則（least privilege）；與網路安全的分段（segmentation）思路一致。

## 🔗 延伸學習路徑

- **下一步應學**：Deployment 與 ReplicaSet（讓 Pod 具備自我修復、多副本與滾動更新）→ 見 [[Lesson_4_Kubernetes_Deployments_and_ReplicaSets]]；接著 Service / Ingress 把 Pod 對外曝露 → [[Lesson_5_Kubernetes_Services_and_Networking]]；再到 ConfigMap/Secret、PV/PVC、probe。
- **推薦關鍵字**：`kubectl apply`、declarative vs imperative、`kubectl explain`、`--dry-run=client -o yaml`、namespace、ResourceQuota、LimitRange、resource requests/limits、RBAC、NetworkPolicy、context/kubeconfig、`kubectl config set-context`、CrashLoopBackOff、`kubectl get -A`。
- **相關人物 / 資源 / 文件**：Kubernetes 官方文件（Pods、Namespaces、Resource Quotas、kubectl Cheat Sheet）；CKA/CKAD 認證考綱；本 repo 的 [[gke-deploy]] skill（在 GKE 上實際部署與排查 Pod：Pending / CrashLoopBackOff / ImagePullBackOff / OOMKilled）；本系列 [[Lesson_2_Kubernetes_Architecture]]（etcd、scheduler、API Server 職責）。
- **在知識地圖中的位置**：本講是「觀念 → 操作」的橋樑——把叢集元件落地成可敲的 `kubectl` 指令與 namespace 邊界，是後續所有更高階工作負載（Deployment、Service、Job、StatefulSet）與治理（RBAC、Quota、Policy）的共同地基。

> 校正說明（ASR 修正）：逐字稿為自動轉錄，本筆記已將明顯同音／誤植校正為標準術語——「cube control」→ `kubectl`、「cube system」→ `kube-system`、「Engine X / engine x」→ `nginx`、「pod manifest dot yml」→ `pod-manifest.yml`、「dash f / dash n」→ `-f` / `-n`、「memory one gig」→ memory 1 Gi、「fivefold」類非本文——並將口語（"cube control get"）統一為指令格式。YAML manifest 與部分 `kubectl` 指令為配合教學重建之標準範例（忠於講者描述的欄位與行為，如 `metadata.namespace`、`-n demo`、READY `0/1`→`1/1`、ResourceQuota CPU 1 / memory 1Gi），非逐字稿逐字內容；無法可靠還原的片段未予杜撰。
