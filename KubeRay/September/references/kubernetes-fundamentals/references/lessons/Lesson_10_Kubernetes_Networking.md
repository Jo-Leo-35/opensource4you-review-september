# Kubernetes FULL COURSE：Lesson 10 — Kubernetes Networking：Services、Network Policies 與實機 Demo

> 來源：YouTube 課程逐字稿 + SRT（ASR 自動轉錄，語言標籤誤標為 Chinese，實際內容為英文口語）｜https://www.youtube.com/watch?v=qnAnBTQ3zb4
> 講者：Chad（CKA/CKAD 認證講師，20 年教學經驗；課程隸屬 Alta3 Academy）
> 時長：約 37:56（Part 10，Kubernetes FULL COURSE 最後一講）
> 領域：資訊科學／雲原生（Cloud Native）／DevOps／軟體工程
> 難度：入門到中階（CKA / CKAD 認證基礎，Kubernetes 網路模組）
> 學習目標：理解「為什麼 Pod IP 不可靠」→ Service 如何用穩定的虛擬 IP 與 label selector 追蹤一群動態 Pod → NetworkPolicy 如何用「白名單」控制 Pod 間 ingress/egress 流量 → kube-proxy 與 iptables 如何在底層以 round-robin 實現負載分流 → ClusterIP / NodePort / LoadBalancer 三種 Service 型別的差異與對外暴露方式，並能用 `kubectl` 與 YAML manifest 實作與驗證。
> transcript_source: [[2025-08-08_qnAnBTQ3zb4_Kubernetes-FULL-COURSE-Part-10-Kubernetes-Networking-–-Services,-Policies-&-Demo.txt]]

## 📌 一句話總覽

本講回答一個 Kubernetes 網路的核心痛點：**Pod 是「牛群」不是「寵物」，它們的 IP 位址是一個不斷移動的目標（constantly moving target）**——Pod 被刪除、重建、擴縮（scale up/down）時 IP 幾乎必然改變，連被排到哪個 node 都不保證。既然直接用 Pod IP 通訊不可靠，Kubernetes 引入 **Service** 這個抽象層：它擁有一個「終生不變」的虛擬 IP（以及可被叢集 DNS 解析的名字），並透過 **label selector** 動態追蹤符合條件的一群 Pod 的即時 IP（endpoints）。只要你握有 Service 的 IP 或名字，就永遠能被導向正確的、活著的 Pod。第二個主題是 **NetworkPolicy**：預設情況下叢集內「人人可通」（peace and love），這是資安災難；NetworkPolicy 像「直升機父母」一樣，以白名單方式規定「哪些 Pod 只能收（ingress）／發（egress）哪些流量」，而且遵循「**未明確允許即全部拒絕**」的預設拒絕（default-deny）語意。底層機制由每個 node 上的 **kube-proxy** 撐起：它讀寫 node 的 **iptables**，以 **round-robin** 在多個健康的 Pod 間分流，且所有 node 共享同一份路由表，因此「Pod 在哪個 node 上」對呼叫端完全透明。最後貫穿 **ClusterIP → NodePort → LoadBalancer** 三種逐層堆疊的 Service 型別，示範如何從叢集內部通訊一路擴展到對外暴露服務。本講是整套課程的收尾（從 YAML 一路講到 networking），也是 CKA/CKAD 考試的必考題。

## 🧭 知識地圖（Knowledge Map）

- **前置知識**：Pod、Deployment、ReplicaSet（副本管理）、label 與 selector、namespace、`kubectl` 基本操作、容器 port 概念、YAML 語法；對 IP / TCP port / DNS 的基本網路直覺（見 [[Lesson_1_Kubernetes_Introduction]]、[[Lesson_5_Deployments_ReplicaSets]]）。
- **本集核心**：
  - Service 抽象：穩定虛擬 IP + label selector + endpoints 動態追蹤。
  - 三種 Service 型別：ClusterIP（叢集內）、NodePort（對外最原始）、LoadBalancer（雲端外部負載平衡器）。
  - Pod-to-Pod 通訊與叢集內建 DNS（用 Service 名稱當主機名）。
  - NetworkPolicy：namespace 綁定、podSelector、policyTypes、ingress/egress 規則（ipBlock / namespaceSelector / podSelector / ports）、default-deny、白名單 OR 語意。
  - kube-proxy + iptables：Service 的底層實作、round-robin 分流、健康檢查過濾、跨 node 一致路由表。
  - Service manifest 的 `port` vs `targetPort`（含多容器多 port 映射）。
  - `kubectl port-forward` 與 NodePort 的對外存取差異。
- **後續會連到**：Ingress（L7 HTTP 路由，Service 的上層）、CoreDNS 服務發現細節、CNI 外掛（Calico/Cilium 實作 NetworkPolicy）、Service Mesh（Istio/Linkerd）、雲端 LoadBalancer 與 Cloud Controller Manager、[[gke-deploy]] skill 中的 GKE Service/Ingress 實務。
- **可跨領域連結**：計算機網路的 [[Lecture_1_Network_Architecture_OSI_7_Layer]]（L2/L3/L4 分層、routing table、NAT）、[[Lecture_8_TCP_Congestion_Control]]（TCP 連線與 port）、分散式系統的服務發現與負載平衡（[[distributed-systems-advisor]]）、資安的最小權限原則（least privilege）與零信任（zero trust）。

## 🎯 核心重點（Core Takeaways）

- **Pod IP 是「不斷移動的目標」**：Pod 被刪除重建後幾乎不會拿回同一個 IP，甚至不保證被排到同一個 node；因此任何「把 Pod IP 寫死」的通訊方式在 Kubernetes 中都是錯的，這正是需要 Service 的根本原因。
- **Service 的價值在於「一個永不改變的 IP」**：當一群 Pod 的 IP 全都在變動時，唯一不變的就是 Service 的 IP；只要你知道 Service 的 IP（或名字），Service 就會把你導向正確且存活的 Pod（「the method behind the madness」）。
- **Service 用 label selector 動態追蹤 endpoints**：`kubectl describe` 一個 Service 會看到它自身的 IP，以及它目前匹配到的所有 Pod IP；把 Deployment 從 3 個副本縮到 1 個或擴到 10 個時，Service 的 endpoint 清單會自動同步增減，而 Service 自身的 IP 始終不動。
- **叢集內建 DNS 讓你用 Service 名稱通訊**：在一個 Pod 內 `wget <service-name>` 即可連到該 Service 背後的 Pod（範例中下載到 nginx 的 `index.html` 歡迎頁），不需要記任何 IP——這就是 Kubernetes 的服務發現（service discovery）。
- **預設「人人可通」是資安災難**：Service 一旦建立，叢集內任何 Pod 都能存取被它暴露的 Pod（甚至跨 namespace）；這種「peace and love」預設狀態必須用 NetworkPolicy 加以約束。
- **NetworkPolicy 綁定 namespace 並用 podSelector 選定受控 Pod**：它像 resource quota / limit range 一樣掛在某個 namespace 上，`podSelector` 以 `matchLabels` 指定「哪些 Pod 要被『直升機父母』管教」；`podSelector: {}`（空的大括號）代表選中該 namespace 內的**所有** Pod。
- **NetworkPolicy 是白名單且 default-deny**：`policyTypes` 宣告要控制 Ingress、Egress 或兩者；一旦某 Pod 被某條 policy 選中，「凡是規則沒明確允許的流量一律拒絕」；若只寫了 podSelector 卻沒給任何 ingress/egress 規則，就形成 **default deny**（範例中 `wget` 直接 hang 住連不上）。
- **Ingress/Egress 的來源可用三種選擇器，且彼此是「OR」關係**：`ipBlock`（CIDR 網段，可含 `except` 例外）、`namespaceSelector`（依 namespace 上的 label）、`podSelector`（依 Pod 上的 label，最常用）；三者列在同一 `from`/`to` 清單中時是「滿足任一即可」的 OR 語意，設定時務必在測試環境仔細驗證。
- **Pod 可跨 namespace 互相通訊**：即使 Pod 在不同 namespace，只要被 Service 暴露就「不安全」——別的 namespace 的 Pod 也能存取它；因此 `namespaceSelector` 是控制跨 namespace 流量的關鍵工具。
- **Service manifest 的 `port` 與 `targetPort` 意義不同**：`targetPort` 是**目標容器**上的 port（例：nginx 的容器 port 固定是 80），`port` 是 **Service 自身**對外開放的 port；兩者建立映射，讓「連到 Service IP 的某 port」被轉發到「容器的某 port」。
- **一個 Service 可映射多個 port 到 Pod 內不同容器**：因為一個 Pod 可含多個容器，Service 可設定「port 4444 → targetPort 8888」等額外映射，讓不同 port 進入同一 Pod 的不同容器/應用。
- **kube-proxy 是 Service 的底層引擎**：每個 node 都有一個 kube-proxy（如同每個 node 都有 kubelet），它能存取該 node 的 **iptables**；它查 Service 表，找到 Service 對應的 Pod IP 後設定路由規則，讓封包最終抵達 Pod。
- **kube-proxy 預設用 round-robin 分流並過濾不健康的 Pod**：當 Service 背後有多個副本時，kube-proxy 輪流選擇（上次選 1.3.1、這次選 1.3.2）；且選擇前會確認 Pod 健康，若 Pod 還在 ContainerCreating 或 error 就跳過選下一個。
- **所有 node 的路由表完全相同，位置無關（location-transparent）**：不論叢集有 1 個還是 50 個 node，每個 node 的 kube-proxy 都握有相同的路由資訊；因此「呼叫端 Pod 與目標 Pod 是否在同一 node」完全不重要，reaching a pod on another node 是完全正常的。
- **三種 Service 型別逐層堆疊**：ClusterIP（預設，只供叢集內通訊）→ NodePort（在每個 node 開一個 30000–32767 的 port，外部只要有 node IP + node port 即可存取，是最原始的對外方式）→ LoadBalancer（仍使用 node port，但額外要求一台叢集外、具對外 IP 的負載平衡器，雲端 Azure/AWS 會替你開；Kubernetes 本身不內建 LoadBalancer）。
- **`kubectl port-forward` 只是臨時的本機除錯通道**：它需要 `kubectl` 存取權才能 `curl localhost:<port>`；NodePort 則讓你用純 `curl <nodeIP>:<nodePort>` 從外部存取、完全不需 `kubectl`——這是 CKA/CKAD 幾乎必考的區別。

## 🔑 關鍵字與術語表（Keywords & Glossary）

| 術語 | 原文 / 符號 | 說明 |
|---|---|---|
| 服務 | Service | 為一群動態 Pod 提供穩定虛擬 IP 與 DNS 名稱的抽象物件；用 label selector 追蹤後端 Pod |
| 叢集內部 IP 服務 | ClusterIP Service | 預設 Service 型別；只在叢集內部可達，供 Pod-to-Pod 通訊 |
| 節點埠服務 | NodePort Service | 在每個 node 開放一個 30000–32767 的 port，外部可用 `<nodeIP>:<nodePort>` 存取 |
| 負載平衡器服務 | LoadBalancer Service | 建於 NodePort 之上，需外部負載平衡器（雲端自動佈建）以對外 IP 接流量 |
| 端點 | endpoints | Service 目前匹配到的後端 Pod IP 清單，隨 Pod 增減自動更新 |
| 部署 | Deployment | 宣告式管理一組相同 Pod（副本）的工作負載物件 |
| 副本 | replicas | Deployment 要維持的 Pod 數量 |
| 容器組 | Pod | Kubernetes 最小部署單位，可含一個以上容器，擁有自己的（易變的）IP |
| 標籤 / 標籤選擇器 | label / selector | key=value 標記；Service、NetworkPolicy 皆用 `matchLabels` 依 label 選中 Pod |
| 命名空間 | namespace | 叢集內的邏輯隔離區；NetworkPolicy 綁定於 namespace |
| 網路政策 | NetworkPolicy | 以白名單控制 Pod 間 ingress/egress 流量的物件（「直升機父母」） |
| 進入流量 | ingress | 進入 Pod 的流量（注意：與 Ingress 資源不同概念） |
| 送出流量 | egress | 從 Pod 送出的流量 |
| 政策類型 | policyTypes | NetworkPolicy 宣告要控制 Ingress / Egress / 兩者的欄位 |
| Pod 選擇器 | podSelector | NetworkPolicy 中指定「受本 policy 管控」的 Pod；`{}` 表示所有 Pod |
| 命名空間選擇器 | namespaceSelector | 依 namespace 上的 label 允許來源/目的流量 |
| IP 區塊 | ipBlock | 用 CIDR（cipher/CIDR range）指定允許的 IP 網段，可加 `except` 例外 |
| 預設拒絕 | default deny | 被 policy 選中但無任何允許規則時，全部流量被拒 |
| 無類別網域路由 | CIDR（逐字稿誤作 "cipher"）| 表示 IP 網段的表示法，如 `172.16.0.0/16` |
| 叢集 DNS | cluster DNS（CoreDNS）| 讓 Pod 以 Service 名稱解析出 Service IP 的服務發現機制 |
| 目標埠 | targetPort | Service 映射到的**容器**上的 port（如 nginx 容器 port 80） |
| 服務埠 | port | Service 自身對外開放的 port |
| 節點埠 | nodePort | NodePort Service 在每個 node 上開的 port，範圍 30000–32767 |
| 埠轉發 | port-forward | `kubectl port-forward`，把本機 port 導入 Pod，供臨時除錯 |
| 代理 | kube-proxy | 每 node 一個；操作 iptables 實現 Service 的封包轉送與分流 |
| 節點代理 | kubelet | 每 node 一個的 node agent（此處拿來類比 kube-proxy 的普遍性） |
| IP 表 | iptables | Linux 核心的封包過濾/NAT 規則表；kube-proxy 藉此路由 Service 流量 |
| 輪詢 | round robin | kube-proxy 預設的後端 Pod 選擇策略（依序輪流） |
| 忙碌盒 | BusyBox | 精簡 Linux 映像，內含 `wget` 等工具，常用作測試/除錯 client Pod |
| 網頁抓取工具 | wget / curl | 命令列 HTTP 下載工具，用來驗證網路連通性 |
| 認證考試 | CKA / CKAD | Certified Kubernetes Administrator / Application Developer 認證 |

## 📖 詳細筆記（Detailed Notes）

### 1. 開場與「快速髒版」Deployment [00:00:00–00:00:46]
**本段回答的問題**：Kubernetes 網路要從哪裡開始講？先準備什麼實驗素材？

- **切入風格**：講者強調「showing rather than telling」（示範勝於空談），所以直接動手建東西。這是本講的教學基調——先看現象，再解釋機制。
- **建立 Deployment**：建立一個使用 **nginx** 映像的 Deployment，指定 port 為 **80**，並要求 **3 個 Pod**（replicas=3）。
- **關鍵細節（埋伏筆）**：指定 port 時「需要在前面加兩個 dash（`--`）」，講者說「這在後面很重要」——這是 `kubectl create deployment ... --port=80` 的旗標寫法，後續談 Service 的 `port`/`targetPort` 時會呼應。
- **關聯**：這個「nice quick and dirty deployment」是後面所有 Service、NetworkPolicy 示範的舞台。

### 2. 核心痛點：Pod IP 是「不斷移動的目標」 [00:00:46–00:02:32]
**本段回答的問題**：為什麼不能直接用 Pod 的 IP 來通訊？Service 到底解決什麼？

- **比喻**：Pod 要能被通訊到，需要一個「拉斯維加斯般閃爍的巨型霓虹燈招牌」大喊「就在這裡！你要找的 Pod 在這裡！」——這就是 Service 的角色。
- **現象展示**：`kubectl get pods -o wide`（get 額外欄位）可見**每個 Pod 都有自己唯一的 IP**。
- **關鍵實驗**：刪掉第一個 Pod（IP 尾碼 247.34，在 node 2 上）。Pod 一定會被 Deployment 重建，但重建後：
  - **不保證拿回同一個 IP**（範例中變成完全不同的 IP）。
  - **不保證排到同一個 node**（範例中恰好仍在 node 2，是因 scheduler 判斷 node 2 較空，屬巧合）。
- **結論**：隨著 Deployment 擴縮、Pod 被刪除重建，**IP 位址是一個 constantly moving target**。這就是 Kubernetes 網路的「惡夢」，也是 Service 存在的理由。
- **關聯**：呼應「Pod 是可拋棄的（cattle, not pets）」設計哲學（見 [[Lesson_5_Deployments_ReplicaSets]]）。

### 3. `kubectl expose`：建立 ClusterIP Service 並動態追蹤 endpoints [00:02:32–00:05:27]
**本段回答的問題**：Service 怎麼建？它如何「永遠知道 Pod 在哪」？

- **建立方式**：雖然可以寫 manifest，但這裡用命令列：`kubectl expose deployment demo-deploy`。結果誕生一個新型物件 **Service**，且它**擁有自己的 IP**。
- **型別**：這樣建出來的、也是最常見的，是 **ClusterIP** service（三種型別之一，後述）。
- **describe 觀察**：`watch kubectl describe service demo-deploy` 可見：
  - Service 自身 IP（範例 `172.16.3.105`）。
  - 另外「一、二、三」個 IP——這些正是**被 selector 匹配到的所有 Pod 的 IP**（即 endpoints），每個 Pod 都被「配對」進來。
- **動態追蹤實驗**：
  - 把 `demo-deploy` 從 3 副本 **縮到 1**：兩個 Pod 被刪，Service 的 endpoint 清單**自動**只剩那一個存活 Pod 的 IP。
  - **擴到 10**：endpoint 立刻變成 10 個 IP。
- **關鍵洞察**：在所有變動的 Pod IP 之間，**唯一從頭到尾沒變過的就是 Service 的 IP**。所以「Service 永遠知道 Pod 的 IP，而 Pod IP 一直在變；只要你知道 Service 的 IP，你就穩了（you're gold）」——Service 會把你指向正確方向。這就是「the method behind the madness」。
- **關聯**：endpoints 的自動維護由 control plane（endpoints/EndpointSlice controller）完成，是宣告式協調（reconciliation）的又一例。

### 4. Pod-to-Pod 通訊實測：用 Service 名稱 + BusyBox client [00:05:27–00:07:20]
**本段回答的問題**：其他 Pod 如何實際連上被 Service 暴露的 Pod？要記 IP 嗎？

- **設置測試 client**：建立一個名為 `client` 的 Pod，跑 **BusyBox** 映像。BusyBox 的好處是內建 `curl`、`wget` 等工具，方便測連通性。
- **執行**：`kubectl exec` 進入 client Pod，改用 **`wget`**（講者本想用 curl，臨時改 wget），指令是 `wget <service 名稱 demo-deploy>`。
  - 因為 Service 指向的 Pod 跑的是 nginx，`wget` 抓回了 **`index.html`**——正是 nginx 的「Welcome to nginx」歡迎頁。
- **關鍵結論**：這就是 **Pod-to-Pod communication**，而且**用的是 Service 名稱、不是 IP**——叢集內建 DNS 把 Service 名稱解析成 Service IP（服務發現）。
- **順勢帶出問題**：「right now every pod inside of our cluster is able to do that」——目前叢集內**任何** Pod 都能存取這些 Pod。「It's peace and love, everybody loves everybody... **That's a security nightmare.**」
- **關聯**：直接引出下一節的 NetworkPolicy。

### 5. 資安問題浮現：為何需要 NetworkPolicy [00:07:20–00:08:07]
**本段回答的問題**：Pod 之間確實需要通訊，但「全部都能通」為什麼危險？怎麼辦？

- **矛盾點**：Pod 之間**確實需要**通訊（yes, pods do need to communicate），但我們**也需要規則**規定「哪些 Pod 允許跟哪些 Pod 講話」。
- **解法登場**：建立新型物件 **NetworkPolicy**。
- **講者誠實預告**：從他教過的數百名學生經驗看，NetworkPolicy 是「你會見過最惡夢的 manifest」；但只要學會這個最長最醜的範例，就沒有任何 NetworkPolicy 能難倒你。
- **關聯**：NetworkPolicy 對應資安的最小權限（least privilege）與零信任（zero trust）思維（見跨領域連結）。

### 6. NetworkPolicy 結構（上）：namespace 綁定、policyTypes、podSelector [00:08:07–00:10:34]
**本段回答的問題**：一個 NetworkPolicy manifest 由哪些主要部分組成？它管的是誰？

- **綁定 namespace**：NetworkPolicy 就像 resource quota、limit range 一樣，是**指派給 namespace** 的；它只影響**該特定 namespace 內**的 Pod。→ **步驟一：先鎖定你想控制的 Pod 所在的 namespace。**
- **spec 拆解（步驟二）**：本質其實很簡單——一切都是在控制 **ingress（進入流量）** 與 **egress（送出流量）**；可以只控制其一或兩者都控。
- **直升機父母比喻**：NetworkPolicy 像個「right on top of their kid all the time」的直升機父母：「我不准你跟街尾那個 Jimmy 講話（他不是好人），我只准你跟隔壁的 Melvin 講話（他是好孩子）」——精準對應白名單控管。
- **`policyTypes`**：列出這條 policy 要控制什麼：`Ingress`、`Egress`、或兩者。
- **`podSelector`**：指定「哪些 Pod 被本 policy 管控」——若 NetworkPolicy 是直升機父母，這裡就是「被管的小孩是誰」。用 **`matchLabels`**（跟 Deployment 一樣，再次印證 label 在 Kubernetes 中極重要）。
  - 範例語意：**在 default namespace 且帶有 label `role=db`** 的 Pod，即將被控管進出流量，且必須滿足特定條件。
- **關聯**：`matchLabels` 是貫穿 Deployment、Service、NetworkPolicy 的共同機制。

### 7. NetworkPolicy 結構（中）：Ingress 規則的三種來源與 OR 語意 [00:10:34–00:13:32]
**本段回答的問題**：ingress 規則怎麼寫？允許的「來源」可以有哪幾種？它們是 AND 還是 OR？

- **規則區塊**：manifest 下半部才是「流量要能通，必須遵守的規則」。`ingress` 下是第一份規則清單：流量必須來自**以下來源之一**。
- **三種來源選擇器**（講者強調「大多數人不會全用，這是他能找到最長最髒的範例」）：
  1. **`ipBlock`**：指定一個 **CIDR（逐字稿誤作 "cipher"）IP 網段**；只有落在此範圍的 Pod 才允許。還能用 **`except`** 宣告例外網段（在此範圍但這幾段除外）。
  2. **`namespaceSelector`**：依 **namespace 本身的 label** 允許。範例：允許來自「任何帶 label `project=my-project` 的 namespace」的 Pod。→ 重點：**Pod 可以跨 namespace 通訊**，只要被 Service 暴露就「不安全」，別的 namespace 的 Pod 也能存取，所以需要這個選擇器。
  3. **`podSelector`**：依**來源 Pod 的 label**允許（最常見用法）。範例：必須來自帶 label `role=frontend` 的 Pod。
- **OR 語意（極重要陷阱）**：把整段串起來——「default namespace 中帶 `role=db` 的 Pod，只能接收來自『此 IP 範圍』**或**『那個 namespace』**或**『帶此 role 的 Pod』的流量」。**這些是「或（OR）」的情境**，滿足任一即放行。務必在**測試環境**非常精確地確認這正是你要的語意。
- **Ingress ports**：還可限制「被管控的 Pod 只能從特定 port 收流量」，例如只准 port **6379**（Redis 預設 port）；也可列多個 port。
- **關聯**：OR 語意誤解是實務中常見的 NetworkPolicy bug 來源（見常見誤解）。

### 8. NetworkPolicy 結構（下）：Egress 規則 [00:13:32–00:14:32]
**本段回答的問題**：控制「送出」流量跟控制「進入」有何不同？

- **對稱設計**：Egress 用的語言幾乎與 ingress 完全相同。範例：「default namespace 中帶 `role=db` 的 Pod，只允許把流量**送到**『那個 IP 範圍內的 Pod』，且送出時只准送到對方的 port **5978**」。
- **彈性組合**：ingress 與 egress 兩段裡的各種選擇器/port 都可以**混搭（mix and match）**，也可以完全不寫（perfectly fine）。
- **紀律叮嚀**：「be very precise... and **test, test, test**」——NetworkPolicy 規則精確度攸關資安，一定要反覆測。
- **關聯**：egress 控制常用於限制 Pod 只能連特定外部服務或 DNS，是資料外洩防護（DLP）的一環。

### 9. NetworkPolicy 實戰：default-deny 現象與逐步放行 [00:14:32–00:18:23]
**本段回答的問題**：套用 NetworkPolicy 後實際會怎樣？如何從「全擋」修正成「只放行需要的」？

- **無 policy 時**：系統中沒有任何 NetworkPolicy，client Pod 對 nginx Pod 送請求 → 成功下載 `index.html`。
- **套用 default-deny policy**：
  - 這個 policy 的 `podSelector: {}`（**空的大括號 = 選中該 namespace 內所有 Pod**）。
  - 它宣告「default namespace 中所有 Pod 即將被規定『允許從哪收、允許往哪發』」。
  - **但沒有給任何規則**！關鍵原理：**NetworkPolicy 是白名單——只要你做的事不在「被允許」清單內，就完全不被允許。**
  - 結果：再次執行 `wget` → **hang 住、連不上**。這就是 **default deny**（policy「打了我們的手」）。
- **修正流程**（把 default-deny 收斂成精準白名單）：
  1. 查 client Pod 的 manifest，發現它帶 label **`run=client`**。
  2. 查 Deployment Pod 的 label，發現全帶 **`app=demo-deploy`**。
  3. 把 `podSelector` 從 `{}` 改成 **`matchLabels: {app: demo-deploy}`**——policy 不再管全 namespace，只管那些 Deployment Pod。
  4. 不管 egress，只關心進入 nginx Pod 的 **ingress**。
  5. 在下方指定 ingress 來源：**只允許帶 label `run=client` 的 Pod** 進入。
  6. `kubectl apply` 更新 policy。
- **驗證**：client（BusyBox）Pod 再跑一次 `wget` → **成功**。「我們成功設定了這個特定互動被允許，而這些 Deployment Pod 的任何其他互動都會被禁止。」
- **關聯**：這正是「先 default-deny，再逐條開白名單」的資安最佳實務。

### 10. Service manifest 剖析：`port` vs `targetPort` 與多 port 映射 [00:18:23–00:21:06]
**本段回答的問題**：先前用 `kubectl expose` 建的 Service，寫成 manifest 長怎樣？那些 port 數字各是什麼意思？

- **manifest 結構**：不算太難。同樣用 **`selector`**（與 Deployment、NetworkPolicy 一致）指定「本 Service 影響哪些 Pod」——selector 選中帶特定 label 的 Pod。
- **兩個 port 的意義**：
  - **`targetPort`**：指的是**目標（容器）上的 port**。因為 Pod 跑 nginx，而 **nginx 的容器 port 固定是 80**（「written in stone」，不可改）。
  - **`port`**：是 **Service 自身**上的 port。
  - **映射關係**：「若你連到這個 Service 的 IP、在這個 `port`（範例 3423），它會把你導到容器的那個 `targetPort`（80）到 nginx 容器，讓你存取應用」。
- **為何需要這層映射（多容器情境）**：一個 Pod 可能有**多個容器**。若 Service 要把流量導到某 Pod，如何存取「我要的那個特定容器」？答案：靠 port 映射。
  - 例：連 Service 的某 port → 進 nginx 容器的 port 80。
  - **還可再加一組**：`port 4444 → targetPort 8888`，導到同一 Pod 內跑其他應用的另一個容器。
- **結論**：Service 可設定多組 port，導向同一 Pod 內**不同容器/不同應用**。「這就是 port、targetPort 的差別——而且 port 多得很（ports-a-plenty），接下來要講 node port。」
- **關聯**：`port`/`targetPort`/`nodePort` 三者的層次是 NodePort 一節的鋪陳。

### 11. 底層機制：kube-proxy 與 iptables（單一 Pod 的簡單情況）[00:21:06–00:24:12]
**本段回答的問題**：Service「把你導向正確 Pod」這件事，底層到底怎麼發生的？

- **動畫情境**：最簡單的叢集——1 個 node、2 個 Pod 在同 node 上。Pod #1 想跟 Pod #3 講話。
- **前提**：Pod #3 必須先被 Service 暴露（假設 Service 已建好）。問題是：Service 怎麼被定位、被存取？
- **主角登場——kube-proxy**：
  - kube-proxy「很像 kubelet」（Kubernetes 愛把 "kube" 塞進所有東西的名字）。
  - **每個 node 上都有一個 kube-proxy**。
  - kube-proxy 能存取**該 node 的 iptables**（IP 表）。
- **運作**：kube-proxy 看到「有個叫 pod-three 的 Service，它暴露的 IP 是 `10.1.2.1`（即那個 Pod 的 IP）」。此例 Service 只指向一個 Pod，工作很簡單：查 Service → 見只有一個 Pod → 把該 IP 給呼叫端 → routing 就能發生。「一旦定位到 Pod 的 IP，就 game over（達成目標）。」
- **持續的難題**：真實叢集有數十上百個 Pod、IP 不斷改變，所以需要「在這團混亂之上」的方法——即接下來的 round-robin 與跨 node 一致路由。
- **關聯**：iptables 屬於 Linux 網路堆疊（L3/L4 NAT），連到 [[Lecture_1_Network_Architecture_OSI_7_Layer]] 的 routing table 概念。

### 12. kube-proxy 的 round-robin 分流與健康過濾（多副本情況）[00:24:12–00:26:00]
**本段回答的問題**：當 Service 背後有多個相同的 Pod 時，kube-proxy 怎麼選要連哪一個？

- **情境升級**：一個 Pod 想連 `zombie` Deployment 裡的某個 Pod。因為這些 Pod 都是**完全相同的副本（replicas）**，連哪一個都無所謂。
- **kube-proxy 的決策**：
  - 查它的 **service table**，找到 `zombie`，看到有**三個 IP** 可選。
  - kube-proxy 負責設定/遵守「哪個 IP 被選中」的規則，**預設用 round-robin（輪詢）**：上次送到 `1.3.1`，這次就送到 `1.3.2`。
  - 所以是 kube-proxy 最終決定三個 Pod 中哪一個來服務這次請求。
- **健康過濾（重要）**：選擇前 kube-proxy 會**確認該 Pod 是健康的**；若 Pod 還在 **ContainerCreating** 或正在 **erroring out**，就不選它，**跳到下一個**。範例中最後選了 node 2 上的 Pod。
- **關聯**：健康過濾依賴 readiness probe 等機制（見 [[Lesson_8_Health_Probes]]）；round-robin 是最基本的負載平衡策略（見 [[distributed-systems-advisor]]）。

### 13. 多 node 叢集：路由表處處相同、位置無關 [00:26:00–00:28:12]
**本段回答的問題**：在多 node 叢集中，「Pod 在哪個 node」會影響通訊嗎？

- **情境**：Deployment 造出 3 個相同 Pod——2 個在 node 2、1 個在 node 3（純屬排程結果）。
- **關鍵觀察**：關於 kube-proxy 的一切都**套用到所有 node**。看每個 node 上的路由表——**它們全都一樣**。不論叢集是 1 個還是 50 個 node，**任何 node 上的 kube-proxy 都握有相同的路由資訊**。
- **位置無關（location transparency）思想實驗**：node 3 上的 BusyBox Pod 要連某個 zombie Pod，向 kube-proxy 要一個 Pod。kube-proxy **不保證**選 `10.1.2.1`——「that is not important, it can't be important」，它就是用 round-robin 選下一個。所以你的 Pod 可能連到**別的 node 上**的 Pod，**那完全 OK**。
- **論證**：反正若那個 Pod 建在 node 1 上、要連 zombie，也遲早得連到別 node 的 Pod；因為叢集永遠混亂，**不該浪費時間去想「這個 Pod 跟那個 Pod 是否同 node」——that doesn't matter。**
- **關聯**：跨 node 流量由 CNI（overlay 或 routing）承載，是 Kubernetes 網路模型「所有 Pod 可互通、無需 NAT」的前提。

### 14. 三種 Service 型別：ClusterIP → NodePort → LoadBalancer [00:28:12–00:32:46]
**本段回答的問題**：至今講的都是哪種 Service？如何讓外部世界存取叢集？

- **回顧**：前面所有 Pod-to-Pod 通訊用的都是 **ClusterIP** service。三種型別**逐層堆疊（build on the one before）**：
- **① ClusterIP（叢集內部）**：預設型別；只在叢集內可達。
- **② NodePort（對外最原始）**：
  - Service 除了 ClusterIP，還多一個 **node port**，數字**永遠在 30000–32767 之間**（「thirty thousand to thirty-two thousand something」），非常好辨認。
  - 它是「**不需要 `kubectl` 就能從外部存取叢集**」的最原始型別。
  - 機制：只要 client 握有**任一 node 的 IP** + **該 Service 的 node port**，就能存取被指向的 Pod。
  - 走查範例：`curl 192.168.0.12:31234`（node IP:node port）→ 到達該 node 的 port 31234（zombie service 的 node port）→ kube-proxy 認出「你要連 zombie」→ **仍是 round-robin** 選 Pod → 可能選到 `10.1.3.2`（在 node 2 上），**即使你 curl 的是 node 3**，也會連到 node 2 的 Pod，完全正常。
  - 直覺論證：若叢集有 50 個 node、目標只有 1 個 Pod，你猜對正確 node 的機率只有 1/50，「that couldn't possibly work」——所以位置無關是必要設計。
- **③ LoadBalancer（雲端外部負載平衡器）**：
  - 更精緻；**仍然使用 node port**。
  - 需要一台**叢集外、具對外 IP** 的機器來接收 incoming traffic。
  - 若叢集在雲端，Azure/AWS 會（收費）替你 spin up 一個 load balancer；**Kubernetes 本身不內建 LoadBalancer**，只是樂於配合你提供的 LB。
  - 好處：client 連到 load balancer（而非直接連某 node）；LB 會做**真正的負載平衡決策**（「enough of this round robin stuff which is not true load balancing」），做出更明智的 Pod 選擇；因為 LB 也用 node port，它能透過 node port 存取 iptables、選任一 node 上想要的 Pod 並 chart routing。
- **關聯**：LoadBalancer 之上還有 Ingress（L7 HTTP 路由）；GKE 上的實務見 [[gke-deploy]] skill 與 [[Lesson_11_Ingress]]。

### 15. NodePort CLI 實測：port-forward vs NodePort 對外存取 [00:32:46–00:36:19]
**本段回答的問題**：怎麼用 `kubectl` 實際建 NodePort service？它跟 `port-forward` 差在哪？

- **先用 port-forward（臨時除錯）**：
  - 對一個 Pod 開 `kubectl port-forward`，本機 port **2224 → 容器 port 80**。
  - 只要 port-forward 開著，就能 `curl localhost:2224`。
  - Pod 內有一個 `/static` 端點，放著檔案 `nginx.txt`，內容是「**you done did a networking**」。
  - **重點**：port-forward **需要 `kubectl` 存取權**才能透過 localhost 進到容器——這是它的限制。
- **改用 NodePort service**：
  - `kubectl expose pod nginx-configured --type=NodePort`（**必須明確指定 `--type=NodePort`**，否則預設是 ClusterIP）。
  - `kubectl describe` 該 service：type 顯示 **NodePort**，且多出 **`nodePort` 欄位**，自動指派了 **30337**（需記住）。
- **從外部 curl（不需 kubectl）**：
  - `kubectl get nodes -o wide` 取得 node 1 的 IP（範例 `10.14.24.245`）。
  - `curl 10.14.24.245:30337/static/nginx.txt` → 回傳「you done did a networking」。**這是純 curl，完全沒用 `kubectl` 或任何特殊權限**，只需 node IP + node port。
  - **證明位置無關**：改用 node 2 的 IP、相同 node port → **一樣成功**。因為「kube-proxy is everywhere」，node port 在叢集任何位置都可存取、可追蹤到 Pod。
- **考試提醒**：若要考 **CKAD / CKA**，幾乎**必有一題 NodePort service 相關**。
- **關聯**：port-forward 適合開發除錯，NodePort/LoadBalancer 才是正式對外；三者的取捨見深層理解。

### 16. 課程收尾與 CKA/CKAD 準備 [00:36:19–00:37:56]
**本段回答的問題**：整套課程講到哪了？接下來還要學什麼？

- **收尾定位**：「that's our crash course in Kubernetes fundamentals」——本套課程從 **YAML 一路涵蓋到 networking**。
- **仍待學習**：要（尤其為了通過 **CKA / CKAD**）真正精通 Kubernetes，還有很多要學；建議「get your hands dirty」動手做。
- **資源推廣**：講者推薦 **Alta3 Academy**（含與 demo 相同的實作環境、AI 講師、CKA/CKAD 完整模擬考）。
- **關聯**：本講是系列最後一講；延伸應學 Ingress、Helm、StatefulSet、RBAC、儲存（PV/PVC）等（見延伸學習路徑）。

## 🛠️ 實作範例（YAML Manifest 與 kubectl 指令）

> 以下 manifest 依逐字稿情境重建（label、port、名稱皆對齊講者示範），可作為複習與 CKA/CKAD 練習的骨架。

### A. 命令式（imperative）：逐字稿實際用的指令流

```bash
# 1) 建立 nginx Deployment：3 副本、容器 port 80（--port 兩個 dash）
kubectl create deployment demo-deploy --image=nginx --port=80 --replicas=3

# 2) 觀察每個 Pod 各有唯一 IP（並看在哪個 node）
kubectl get pods -o wide

# 3) 刪掉一個 Pod，重建後 IP/node 可能都變（證明 IP 是移動目標）
kubectl delete pod <pod-name>

# 4) 用 Service 暴露 Deployment（預設 ClusterIP）
kubectl expose deployment demo-deploy

# 5) describe 看 Service IP 與它追蹤的 endpoints（後端 Pod IP）
watch kubectl describe service demo-deploy

# 6) 擴縮觀察 endpoints 自動同步，但 Service IP 不變
kubectl scale deployment demo-deploy --replicas=1
kubectl scale deployment demo-deploy --replicas=10

# 7) 建測試 client（BusyBox），進去用服務名稱通訊（服務發現）
kubectl run client --image=busybox --command -- sleep 3600
kubectl exec -it client -- wget -qO- demo-deploy          # 抓回 nginx 的 index.html

# 8) 以 NodePort 對外暴露某 Pod（必須明確指定 type）
kubectl expose pod nginx-configured --type=NodePort --port=80
kubectl describe service nginx-configured                 # 記下自動指派的 nodePort，例如 30337

# 9) port-forward（臨時除錯，需 kubectl 權限）
kubectl port-forward pod/nginx-configured 2224:80
curl localhost:2224/static/nginx.txt                      # -> you done did a networking

# 10) NodePort 對外存取（不需 kubectl，只要 node IP + nodePort）
kubectl get nodes -o wide                                 # 取任一 node 的 IP
curl 10.14.24.245:30337/static/nginx.txt                  # 換另一台 node IP 同樣可通
```

### B. 宣告式（declarative）：ClusterIP Service manifest

```yaml
apiVersion: v1
kind: Service
metadata:
  name: demo-deploy
spec:
  type: ClusterIP                 # 預設；只在叢集內部可達
  selector:
    app: demo-deploy              # 用 label 選中後端 Pod（同 Deployment/NetworkPolicy）
  ports:
    - name: web
      port: 3423                  # Service 自身開放的 port
      targetPort: 80              # 後端「容器」的 port（nginx 固定 80）
    - name: other-app             # 一個 Service 可映射多個 port -> 同 Pod 內不同容器
      port: 4444
      targetPort: 8888
```

### C. NodePort Service manifest

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-configured
spec:
  type: NodePort                  # 對外最原始方式
  selector:
    app: nginx-configured
  ports:
    - port: 80                    # Service port（叢集內）
      targetPort: 80              # 容器 port
      nodePort: 30337             # 每個 node 開放的 port，範圍 30000–32767（不寫則自動指派）
```

### D. Default-Deny NetworkPolicy（先全擋）

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: default              # NetworkPolicy 綁定 namespace
spec:
  podSelector: {}                 # 空 {} = 選中 default 內「所有」Pod
  policyTypes:                    # 宣告要控制的方向
    - Ingress
    - Egress
  # 未給任何 ingress/egress 規則 => 白名單為空 => 全部拒絕（wget 會 hang）
```

### E. 精準白名單 NetworkPolicy（只放行 run=client -> app=demo-deploy 的 ingress）

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-client-to-demo
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: demo-deploy            # 只管這些 Deployment Pod（不再是全 namespace）
  policyTypes:
    - Ingress                     # 只關心進入流量
  ingress:
    - from:
        - podSelector:
            matchLabels:
              run: client         # 只允許帶此 label 的 Pod 進入
```

### F. 「最長最髒」的完整範例（ingress 三來源 OR + ports；含 egress）

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: db                    # 受管的「小孩」：default 內帶 role=db 的 Pod
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:                       # 以下三者為 OR（滿足任一即放行）
        - ipBlock:                # 來源 1：CIDR 網段（可設例外）
            cidr: 172.16.0.0/16
            except:
              - 172.16.5.0/24
        - namespaceSelector:      # 來源 2：某 namespace（依 namespace 的 label）
            matchLabels:
              project: my-project
        - podSelector:            # 來源 3：某些 Pod（最常用）
            matchLabels:
              role: frontend
      ports:
        - protocol: TCP
          port: 6379              # 只允許進入此 port（Redis 預設）
  egress:
    - to:
        - ipBlock:
            cidr: 10.0.0.0/24
      ports:
        - protocol: TCP
          port: 5978              # 只允許送到對方此 port
```

> ⚠️ OR/AND 陷阱：`from` 清單中**分開的 `-` 元素**是 OR；若把 `namespaceSelector` 與 `podSelector` 寫在**同一個 `-` 元素**下則是 AND（既在該 namespace 又帶該 label）。務必在測試環境驗證。

## 🧪 例子、案例與應用

- **刪 Pod 觀察 IP 改變**：`kubectl delete pod <name>` 後，重建的 Pod 幾乎必得新 IP、且可能換 node——實證「Pod IP 是移動目標」，是理解 Service 必要性的最佳實驗。
- **scale 觀察 endpoints 同步**：`kubectl scale deployment demo-deploy --replicas=1`（或 `=10`）搭配 `watch kubectl describe service demo-deploy`，可肉眼看到 endpoint IP 清單自動增減，而 Service IP 不動。
- **BusyBox client 測連通**：以 BusyBox Pod 內 `wget <service-name>` 抓 nginx `index.html`，是驗證「服務發現 + Pod-to-Pod 通訊」的標準手法。
- **default-deny 讓 wget hang**：套用只有空 `podSelector: {}`、無規則的 policy 後，`wget` 卡住不回應，直觀展示「白名單、未允許即拒絕」。
- **「you done did a networking」demo**：Pod 內 `/static/nginx.txt`，先用 `kubectl port-forward` 經 localhost 存取，再改用 NodePort 以純 `curl <nodeIP>:<nodePort>/static/nginx.txt` 從外部存取——一個檔案串起 port-forward 與 NodePort 的差異。
- **Redis-風味 port**：NetworkPolicy 範例用 ingress port `6379`（Redis 預設 port）與 egress port `5978`，呼應「資料庫 Pod（`role=db`）只准特定 port 進出」的真實場景。

## ⚠️ 常見誤解與反例

- **誤解**：Service 是「一台代理伺服器/反向代理程序」在轉封包。
  - **釐清**：ClusterIP Service 沒有實體行程在轉發；它是 kube-proxy 寫進每個 node **iptables** 的一組虛擬 IP + NAT 規則。封包在核心層被改寫導向 Pod。
- **誤解**：NetworkPolicy 裡 `from` 清單的多個來源是「同時滿足（AND）」。
  - **釐清**：同一 `from`/`to` 清單中的多個 `ipBlock`/`namespaceSelector`/`podSelector` 元素是 **OR**（滿足任一即放行）。但**在同一個元素內**同時寫 `namespaceSelector` 與 `podSelector`（同一 `-` 條目）則是 **AND**（既在該 namespace 又帶該 label）——這是實務最易踩雷處，務必 test。
- **誤解**：只要沒套 NetworkPolicy，Pod 就受保護。
  - **釐清**：恰恰相反。**無 policy = 全通（allow all）**；NetworkPolicy 是白名單，套上去（且被選中）才開始限制。且「default deny」需要你主動建立空規則 policy。
- **誤解**：NetworkPolicy 一定會生效。
  - **釐清**：NetworkPolicy 需要**支援它的 CNI 外掛**（如 Calico、Cilium）才會被實作；某些預設網路（如純 flannel）不強制執行 NetworkPolicy，套了也沒作用（本講未展開，但為重要實務前提）。
- **誤解**：`port` 就是容器的 port。
  - **釐清**：`port` 是 **Service** 上的 port，`targetPort` 才是**容器**的 port；兩者常不同（範例 Service port 3423 → 容器 targetPort 80）。
- **誤解**：curl NodePort 時，一定會連到「你 curl 的那個 node 上」的 Pod。
  - **釐清**：kube-proxy 用 round-robin 選 Pod，可能導到**別的 node** 上的 Pod；因為所有 node 路由表相同、位置無關。
- **誤解**：LoadBalancer 是 Kubernetes 內建功能。
  - **釐清**：Kubernetes **不內建** LoadBalancer；需雲端供應商或自備外部 LB。裸機（bare metal）需 MetalLB 之類方案。
- **誤解**：`kubectl port-forward` 可作為正式對外暴露。
  - **釐清**：port-forward 只是**需要 `kubectl` 權限**的臨時除錯通道，程序關掉即斷；正式對外要用 NodePort / LoadBalancer / Ingress。

## 🧠 深層理解

1. **核心直覺是什麼？** 用一層「穩定的間接（stable indirection）」把「善變的後端（Pod IP）」與「呼叫端」解耦——Service 是那個永不改變的招牌，label selector 是它與後端的動態連結。這是電腦科學經典的「多一層間接解決一切問題」。
2. **它解決了什麼問題？** Pod 的可拋棄性（ephemeral、cattle-not-pets）帶來 IP 不穩定；Service 提供穩定 endpoint + 服務發現 + 內建負載分流，讓應用之間可以只靠「名字」通訊。NetworkPolicy 則補上「預設全通」的資安缺口。
3. **它犧牲或忽略了什麼？** ClusterIP 的 round-robin 不是「真正的負載平衡」（不看 Pod 實際負載，只輪流）；Service 抽象也隱藏了跨 node 流量的成本（可能多一跳）。NetworkPolicy 的 OR/AND 語意複雜、且依賴 CNI 支援，容易誤設。
4. **它和哪些概念容易混淆？** ①「ingress 流量」（小寫，NetworkPolicy 的進入流量）vs「Ingress 資源」（L7 HTTP 路由物件）；② `port`/`targetPort`/`nodePort` 三層 port；③ kube-proxy（Service 資料面）vs kubelet（node agent）；④ Service（L4）vs Ingress（L7）。
5. **教給初學者的比喻是什麼？** Service = 拉斯維加斯的巨型霓虹招牌（Pod 一直搬家，但招牌位置不變）；NetworkPolicy = 直升機父母（只准小孩跟特定鄰居講話）；kube-proxy = 每個 node 都有的接線生，手上都拿著同一本電話簿（iptables）。
6. **現實使用的最大限制是什麼？** NetworkPolicy 需要相容 CNI 才生效、規則語意易錯；ClusterIP 僅叢集內；NodePort port 範圍受限（30000–32767）且直接暴露 node IP 不夠優雅；LoadBalancer 依賴外部/雲端且要花錢。生產環境通常再疊 Ingress / Service Mesh 來補足 L7 路由、TLS、細緻流量治理。

## 🕒 時間軸索引（Timeline Index）

- 00:00:00–00:00:46：開場、示範導向風格、建立 nginx Deployment（3 副本，port 80）
- 00:00:46–00:02:32：核心痛點——刪 Pod 後 IP/node 都變，Pod IP 是移動目標
- 00:02:32–00:05:27：`kubectl expose` 建 ClusterIP Service，describe 看 endpoints，scale 觀察自動追蹤、Service IP 不變
- 00:05:27–00:07:20：BusyBox client + `wget <service>` 抓 nginx index.html，服務發現與 Pod-to-Pod 通訊；點出資安問題
- 00:07:20–00:08:07：引入 NetworkPolicy（最惡夢的 manifest）
- 00:08:07–00:10:34：NetworkPolicy 綁 namespace、policyTypes、podSelector、直升機父母比喻
- 00:10:34–00:13:32：Ingress 規則三來源（ipBlock/namespaceSelector/podSelector）、OR 語意、ingress ports
- 00:13:32–00:14:32：Egress 規則（對稱）、mix and match、test test test
- 00:14:32–00:18:23：實戰——default-deny 讓 wget hang，改 podSelector app=demo-deploy + ingress from run=client 修正
- 00:18:23–00:21:06：Service manifest、selector、`port` vs `targetPort`、多容器多 port 映射
- 00:21:06–00:24:12：kube-proxy + iptables，單一 Pod 簡單情況
- 00:24:12–00:26:00：多副本 round-robin 分流 + 健康過濾
- 00:26:00–00:28:12：多 node 叢集，路由表處處相同、位置無關
- 00:28:12–00:32:46：三種 Service 型別 ClusterIP / NodePort / LoadBalancer
- 00:32:46–00:36:19：CLI demo——port-forward vs NodePort 對外存取（you done did a networking）
- 00:36:19–00:37:56：課程收尾、CKA/CKAD 準備、Alta3 Academy

## 💡 重點問答 / 自我測驗

- **Q：為什麼不能直接用 Pod 的 IP 位址來通訊？**
  A：Pod 被刪除/重建/擴縮時 IP 幾乎必然改變，甚至換 node；IP 是「不斷移動的目標」，寫死 Pod IP 的通訊會失效。要用 Service 提供的穩定 IP/名字。
- **Q：Service 如何知道要把流量導向哪些 Pod？**
  A：透過 `selector`（`matchLabels`）匹配帶對應 label 的 Pod，維護一份即時 endpoints（Pod IP 清單），Pod 增減時自動更新。
- **Q：`kubectl expose` 預設建立哪種 Service？**
  A：ClusterIP（只供叢集內部通訊）。要對外需明確 `--type=NodePort` 或 `--type=LoadBalancer`。
- **Q：Service 的 `port` 與 `targetPort` 差在哪？**
  A：`port` 是 Service 自身開放的 port；`targetPort` 是後端容器上的 port（如 nginx 的 80）。Service 把 `port` 映射到 `targetPort`。
- **Q：一個空的 `podSelector: {}` 在 NetworkPolicy 中代表什麼？**
  A：選中該 namespace 內的**所有** Pod。若同時未給任何 ingress/egress 規則，即形成 default-deny。
- **Q：NetworkPolicy 的 `from` 清單中列出 ipBlock、namespaceSelector、podSelector，三者是 AND 還是 OR？**
  A：作為清單中**分開的元素**時是 OR（滿足任一即放行）。但同一個 `-` 條目內同時寫 namespaceSelector 與 podSelector 則是 AND。
- **Q：為什麼套了一個沒有規則的 NetworkPolicy 後，`wget` 會 hang 住？**
  A：NetworkPolicy 是白名單，「未明確允許的流量一律拒絕」；沒有允許規則 = default deny，所有進出被擋，連線卡死。
- **Q：kube-proxy 是什麼？它在哪裡？**
  A：每個 node 上都有一個 kube-proxy，負責讀寫該 node 的 iptables，把 Service 虛擬 IP/NodePort 的流量以 round-robin 導向健康的後端 Pod。
- **Q：kube-proxy 選後端 Pod 時，會不會避開故障 Pod？**
  A：會。選擇前確認 Pod 健康；若 Pod 在 ContainerCreating 或 error，就跳過選下一個。
- **Q：從 node 3 的 IP curl NodePort，為何可能連到 node 2 上的 Pod？**
  A：所有 node 路由表相同、位置無關；kube-proxy 用 round-robin 選 Pod，可能導向任一 node 上的副本，屬正常行為。
- **Q：NodePort 的 port 範圍是多少？**
  A：預設 30000–32767，很好辨認。
- **Q：LoadBalancer Service 與 NodePort 的關係？Kubernetes 有內建 LoadBalancer 嗎？**
  A：LoadBalancer 建於 NodePort 之上（仍用 node port），額外需要一台具對外 IP 的外部負載平衡器；Kubernetes 不內建，需雲端供應商或自備（裸機可用 MetalLB）。
- **Q：`kubectl port-forward` 與 NodePort 對外存取的關鍵差別？**
  A：port-forward 需要 `kubectl` 存取權、經 localhost、屬臨時除錯；NodePort 用純 `curl <nodeIP>:<nodePort>` 從外部存取、不需 `kubectl`。
- **Q：為什麼「Pod 在哪個 node」對通訊不重要？**
  A：每個 node 的 kube-proxy 共享相同路由表，Service 抽象隱藏了 node 位置；round-robin 本就可能跨 node，糾結同 node 反而浪費資源。
- **Q：預設情況下叢集內 Pod 之間的可達性如何？為何是資安問題？**
  A：預設全通（任何 Pod 都能存取被 Service 暴露的 Pod，甚至跨 namespace）；缺乏隔離違反最小權限，需 NetworkPolicy 收斂。

## 🧩 跨領域連結

- **雲原生 ↔ 計算機網路（L2/L3/L4）**：kube-proxy 操作 iptables 做 NAT/routing，正是 [[Lecture_1_Network_Architecture_OSI_7_Layer]] 的 routing table 與封包轉送在容器世界的再現；Service 的 `port` 對應 TCP/UDP port（見 [[Lecture_8_TCP_Congestion_Control]]）。
- **雲原生 ↔ 分散式系統**：Service = 服務發現 + 負載平衡（round-robin），是分散式系統的核心構件；健康過濾對應故障偵測與流量摘除（見 [[distributed-systems-advisor]]）。
- **NetworkPolicy ↔ 資訊安全**：白名單、default-deny、最小權限（least privilege）、零信任（zero trust）、微分段（micro-segmentation）——NetworkPolicy 是這些資安原則在網路層的落地。
- **間接層 ↔ 電腦科學通則**：「多一層間接解決一切問題（all problems can be solved by another level of indirection）」——Service 對 Pod IP 的抽象即此定律的教科書範例。
- **round-robin ↔ 作業系統排程**：kube-proxy 的輪詢與 CPU 排程的 round-robin 是同一調度思想的不同場景。
- **雲端 LoadBalancer ↔ 經濟／商業**：講者玩笑「Azure/Amazon 愛收你錢」點出雲端受管服務（managed service）的成本 trade-off——便利 vs 費用 vs vendor lock-in。

## 🔗 延伸學習路徑

- **下一步應學**：
  - **Ingress（L7 HTTP/HTTPS 路由）**：Service 之上的第七層路由，支援 host/path 分流與 TLS 終結（見 [[Lesson_11_Ingress]]）。
  - **CoreDNS 與服務發現細節**：Service 的完整 DNS 名稱格式 `<svc>.<namespace>.svc.cluster.local`。
  - **CNI 外掛（Calico / Cilium）**：實際執行 NetworkPolicy 的元件；Cilium 以 eBPF 取代 iptables。
  - **Service Mesh（Istio / Linkerd）**：mTLS、流量治理、可觀測性。
  - **StatefulSet 與 Headless Service**：有狀態應用的穩定網路身分。
- **推薦關鍵字**：`kubectl expose`、`kubectl port-forward`、`endpoints`、`EndpointSlice`、`ClusterIP`/`NodePort`/`LoadBalancer`、`externalTrafficPolicy`、`NetworkPolicy` `ingress`/`egress`、`ipBlock` `except`、`iptables -t nat -L`、`kube-proxy` mode（iptables/ipvs）、`CoreDNS`、`CNI`、`MetalLB`。
- **相關人物 / 資源**：講者 Chad 與 **Alta3 Academy**（含實作環境、AI 講師、CKA/CKAD 模擬考）；官方文件 kubernetes.io 的 Service / NetworkPolicy / Connecting Applications 章節；CKAD/CKA 考綱的 Services & Networking 領域。
- **在知識地圖中的位置**：本講是 Kubernetes FULL COURSE 的收尾（Part 10），把「工作負載（Pod/Deployment）」與「外部世界」用網路縫合；向上接 Ingress/Service Mesh，向下接 CNI/iptables/Linux 網路，橫向連 [[gke-deploy]] skill 的雲端實務。

> 校正說明（ASR 修正）：逐字稿為自動轉錄（語言標籤誤標為 Chinese，實際為英文口語），本筆記已將明顯同音／誤植校正為標準 Kubernetes 術語，包括：「cipher range」→ **CIDR range**（NetworkPolicy 的 ipBlock）；「q control / cube control / kube control」→ **`kubectl`**；「busybots」→ **BusyBox**（另處講者也戲稱其為 client Pod）；「node balancers」（講者當場自我更正）→ **node ports**；「yml」→ **YAML**；口語填充詞（"but but but but"、"zhoop"、"mwah"、"hoo boy"）已略去或轉為說明。示範中出現的具體 IP、port（如 172.16.3.105、3423、30337、6379、5978、port 2224）與 label（`role=db`、`app=demo-deploy`、`run=client`、`role=frontend`、`project=my-project`）皆忠實保留自逐字稿；無法可靠還原的片段未予杜撰。
