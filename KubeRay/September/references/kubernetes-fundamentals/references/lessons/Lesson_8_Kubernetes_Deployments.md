# Kubernetes FULL COURSE Part 8：Kubernetes Deployments — 大規模管理應用（Managing Applications at Scale）

> 來源：逐字稿 + SRT（YouTube，ASR 轉錄）｜https://www.youtube.com/watch?v=fMIlW6GcN-U
> 講者：Chad（CKA / CKAD 認證講師，20 年教學經驗）
> 時長：約 16:33（00:00:00–00:16:33，單一影片 = 本 Lesson）
> 領域：資訊科學 / 雲原生（Cloud Native）/ DevOps（軟體工程）；Kubernetes workload 管理
> 難度：入門到中階（CKA/CKAD 基礎；需先具備 Pod、container、YAML manifest、kubectl、label 概念）
> 學習目標：理解為何生產環境「不該直接建立裸 Pod」，而要用 Deployment；掌握 Deployment 如何透過 **desired state（期望狀態）調節迴圈** 提供自我修復（self-healing）與水平擴縮（scaling）；讀懂並手寫 Deployment manifest（兩層 metadata、`replicas`、`selector.matchLabels`、`template`）；釐清 **Deployment → ReplicaSet → Pod** 的三層責任鏈與 scheduler 的角色；理解 label selector 如何界定「哪些 Pod 屬於我」；掌握 **rolling update（滾動更新）** 的 surge/刪除機制如何達成零停機（zero downtime），以及 **rollback（回滾）** 如何靠切回舊 ReplicaSet 完成；熟悉 `kubectl create/apply/scale/get/label/delete` 與 `kubectl rollout history / undo` 等操作。
> transcript_source: [[2025-08-08_fMIlW6GcN-U_Kubernetes-FULL-COURSE-Part-8-Kubernetes-Deployments-–-Managing-Applications-at-.txt]]

## 📌 一句話總覽

本講處理雲原生維運最核心的一個現實：**Pod 是「用完即丟」的暫時性資源，隨時可能因流量波動、程式錯誤、節點當機或更新而死亡，且裸 Pod（bare Pod）死了不會自己回來**——因此在生產環境幾乎不會單獨建立 Pod，而是透過 **Deployment** 來管理。Deployment 的本質是一個宣告式（declarative）的控制器：你只告訴它「我要幾份、長什麼樣（template）、用什麼 label 認領（selector）」，它就會透過持續執行的**調節迴圈（reconciliation loop）**，讓叢集實際狀態不斷向你宣告的**期望狀態（desired state）**收斂——少了就補、被刪就重建、被搶走 label 就再造一個，永遠維持「不多不少」的副本數（replicas），這就是**自我修復（self-healing）**與**水平擴縮（scaling）**兩大立即好處。更深一層，Deployment 其實不直接造 Pod，而是造出 **ReplicaSet**，由 ReplicaSet 造 Pod，Pod 放到哪個 node 則由 **scheduler** 決定，形成 `Deployment → ReplicaSet → Pod` 的三層責任鏈。Deployment 相對於老牌的 ReplicaSet 多出的殺手級能力是**版本控制**：更新時它不會去改舊 ReplicaSet，而是建立**新的 ReplicaSet**，透過 **rolling update**（先加一個新 Pod、再刪一個舊 Pod，過程中副本數永不低於期望值）達成**零停機更新**，且可用 `kubectl rollout undo` 一鍵**回滾**到前一版（本質是把流量切回舊 ReplicaSet）。本講在 Kubernetes 學習體系中，是從「單一 Pod」跨向「可規模化、可運維、可持續交付的工作負載」的關鍵轉折點。

## 🧭 知識地圖（Knowledge Map）

- **前置知識**：容器與 image（nginx、redis image）、Pod 概念與 Pod manifest（`apiVersion/kind/metadata/spec/containers`）、kubectl 基本操作、Kubernetes label 與 label selector、node 與 cluster 概念、YAML 語法。
- **本集核心**：Pod 的暫時性（ephemeral）與「裸 Pod 不會自癒」；Deployment 的 desired-state / reconciliation 模型；`replicas` 與 `kubectl scale`；self-healing（刪 Pod 自動重建、移除 label 觸發重建）；Deployment manifest 兩層結構（deployment metadata/spec vs pod template）；`selector.matchLabels` 與 `template.metadata.labels` 必須一致；`Deployment → ReplicaSet → Pod` 三層責任鏈與 scheduler；rolling update（maxSurge 概念、逐一替換、零停機）；rollback 與 `kubectl rollout history / undo`；revision（修訂版）概念。
- **後續會連到**：Service 與 label selector 如何對 Deployment 的 Pod 做負載均衡（[[Lesson_9_Kubernetes_Services]]）、Ingress、ConfigMap / Secret 注入、Probe（liveness/readiness）如何影響 rolling update 的健康判定、HPA（Horizontal Pod Autoscaler）自動擴縮、StatefulSet / DaemonSet / Job / CronJob 等其他 workload、`rollingUpdate` 的 `maxSurge` / `maxUnavailable` 細部調參、部署策略（Recreate vs RollingUpdate、藍綠 / 金絲雀）。
- **可跨領域連結**：控制理論的**回授控制（feedback control）與 setpoint 追蹤**（desired state = setpoint）；分散式系統的**狀態機複製與冪等 reconcile**；DevOps / SRE 的**持續交付（CD）與零停機部署**；可靠度工程的**冗餘（redundancy）與容錯**；版本控制系統（Git）的 revision / rollback 心智模型。

## 🎯 核心重點（Core Takeaways）

- **Pod 是暫時性資源，本質上會死**：Pod 會因流量波動（fluctuations in traffic）、程式錯誤、節點當機或更新而消失，「絕不該預期 Pod 會一直存在」；而**裸 Pod（自己單獨建立的 Pod）一旦被刪或死掉就不會回來**，因此不夠可靠（not bulletproof）。
- **生產環境用 Deployment 管理 Pod，而非直接建 Pod**：Deployment 是一個宣告式控制器，你宣告「期望狀態」（要幾份、Pod 長怎樣、用什麼 label 認領），它負責讓實際狀態持續向期望狀態收斂。
- **Deployment 的兩大立即好處是 scaling 與 self-healing**：可透過 `kubectl scale` 或改 manifest 的 `replicas` 隨時擴增 / 縮減副本數；且任何非預期消失的 Pod 都會被自動補回，維持「不多不少（no more, no less）」的固定副本數。
- **Deployment 造出的 Pod 名字繼承 Deployment 名**：`kubectl create deployment demo-deploy --image=nginx` 造出的 Pod 會以 Deployment 名開頭，並附帶隨機字串保證唯一名稱；因此 manifest 中「不需要（也不該）自己替 Pod 命名」。
- **`kubectl scale` 與改 manifest 後 `kubectl apply` 兩種方式等效**：兩者都改變 `replicas`；`scale` 是命令式（imperative）即時調整，改 manifest + `apply` 是宣告式（declarative）調整，後者可版本化管理。
- **label selector 是 Deployment「認領」Pod 的機制**：Deployment 用 `spec.selector.matchLabels`（例：`app: nginx`）宣告「凡是帶這個 label 的 Pod 都屬於我」；`spec.template.metadata.labels` 必須帶上相同 label，否則造出的 Pod 不被自己認得。
- **移除 Pod 的 label 會「騙過」Deployment**：把某個 Pod 的認領 label 拿掉，Deployment 會認為那個 Pod「不見了」，於是**再造一個新 Pod 補足數量**——它並不會去找回失聯的 Pod，只忠實維持副本數。
- **Deployment 的 Pod「幾乎打不死」**：直接刪 Pod 會被立刻重建；要真正清掉所有 Pod，只能**刪除 Deployment 本身**，或把 **`replicas` 縮到 0**。
- **真相：Deployment 不直接造 Pod，而是造 ReplicaSet**：常說「Deployment makes Pods」技術上不精確；實際是 `Deployment → ReplicaSet → Pod`。ReplicaSet 是比 Deployment 更古老的資源，負責「維持固定數量的 Pod」。
- **ReplicaSet 只管數量，不管版本；Deployment 在其上加版本控制**：ReplicaSet 能做的（維持副本數、自癒）Deployment 都能做（因為 Deployment 造 ReplicaSet），但 Deployment 額外能做 **rolling update / rollback 的版本控制**——這正是純 ReplicaSet 在生產環境「難以替換、太麻煩」的痛點解方。
- **Pod 放在哪個 node 由 scheduler 決定**：只要 ReplicaSet 要求的副本數存在，Kubernetes 對 Pod 落在哪個 node「隨遇而安（live and let live）」，除非你另行指定（如 nodeSelector / affinity）。
- **更新時 Deployment 不改舊 ReplicaSet，而是新建一個 ReplicaSet**：對其他資源改 manifest 常會報錯，但 **Deployment「預期並被設計來承接改變」**；更新會產生第二個 ReplicaSet，新舊並存直到切換完成。
- **rolling update 靠「先加後刪、逐一替換」達成零停機**：預設策略下會先 surge（暴衝）一個新 Pod（例：3→4），再刪一個舊 Pod，如此逐一替換，**任何時刻可用 Pod 數都不低於期望值**，客戶端「毫無感覺」——代價是更新過程中會短暫同時存在新舊兩版。
- **無法對執行中的 Pod 加容器，必須重建 Pod**：例如要把每個 Pod 從 1 個 container 變成 2 個（加一個 redis image），因為不能在既有 Pod 上加 container，Deployment 會透過 rolling update 重建全部 Pod。
- **rollback 本質是切回舊 ReplicaSet**：`kubectl rollout history` 查修訂版歷史，`kubectl rollout undo` 把當前 revision 退回前一 revision；因為舊 ReplicaSet 還在（副本數為 0 的形式保留），回滾只是反向做一次 rolling update，同樣零停機、逐一替換。

## 🔑 關鍵字與術語表（Keywords & Glossary）

| 術語 | 原文 / 符號 | 說明 |
|---|---|---|
| 容器組 / 豆莢 | Pod | Kubernetes 最小可部署單位，內含一或多個 container；暫時性、可被隨時替換 |
| 暫時性 / 用完即丟 | ephemeral | Pod 不設計為長存，會因錯誤、擴縮、節點故障或更新而消失 |
| 裸 Pod | bare Pod / naked Pod | 未被任何控制器管理、單獨建立的 Pod；死了不會自動重建 |
| 部署 | Deployment | 管理 Pod 的宣告式控制器，提供 scaling、self-healing、rolling update、rollback |
| 副本集 | ReplicaSet | 維持固定數量 Pod 的控制器；Deployment 在其上加版本控制；比 Deployment 更古老 |
| 副本 | replica(s) | 同一 Pod 的多個克隆；`spec.replicas` 指定期望數量 |
| 期望狀態 | desired state | 你宣告要達成的叢集狀態（幾份、什麼 template、什麼 selector） |
| 調節迴圈 | reconciliation loop | 控制器持續比對實際狀態與期望狀態並修正差異的迴圈；self-healing 的原理 |
| 自我修復 | self-healing | Pod 非預期消失時，控制器自動重建以維持副本數 |
| 水平擴縮 | scaling (out/in) | 增加或減少副本數；`kubectl scale` 或改 `replicas` |
| 標籤 | label | 附在物件上的 key/value；供其他物件識別與選取，例 `app: nginx` |
| 標籤選擇器 | selector / matchLabels | Deployment 用來「認領」帶特定 label 之 Pod 的條件 |
| Pod 模板 | template | Deployment manifest 中描述「要造出的 Pod 長怎樣」的區塊 |
| 資訊清單 | manifest | 描述 Kubernetes 物件的 YAML / JSON 檔 |
| 命令式 | imperative | 直接下指令做動作，如 `kubectl scale`、`kubectl create deployment` |
| 宣告式 | declarative | 寫下期望狀態交給系統收斂，如改 manifest + `kubectl apply` |
| 滾動更新 | rolling update | 逐一以新 Pod 替換舊 Pod、過程零停機的預設更新策略 |
| 暴衝（超額）| surge / maxSurge | 更新時允許暫時超出期望副本數的 Pod 數量（先加後刪） |
| 零停機 | zero downtime | 更新期間服務不中斷，客戶端無感 |
| 回滾 | rollback / rollout undo | 退回前一個 revision；本質是切回舊 ReplicaSet |
| 修訂版 | revision | Deployment 每次變更產生的一個版本記錄；供查詢與回滾 |
| 部署歷史 | rollout history | `kubectl rollout history` 顯示的修訂版清單 |
| 排程器 | scheduler | 決定 Pod 放到哪個 node 的 Kubernetes 元件 |
| 節點 | node | 執行 Pod 的工作機器（VM 或實體機） |
| 叢集 | cluster | 由多個 node 組成的 Kubernetes 執行環境 |
| 映像檔 | image | 容器映像，例 `nginx`、`redis` |

## 📖 詳細筆記（Detailed Notes）

### 1. Pod 的殘酷宿命：所有 Pod 都會死 [00:00:00–00:00:44]

**本段問題**：為什麼不能把 Pod 當成長期穩定的存在？

- **核心命題**：講者以「the brutal inevitability of what happens to pods（Pod 遭遇的殘酷必然性）」開場——**所有 Pod 都會死，且不該被期望永久存在**。
- **Pod 死亡的原因**（failure modes）：流量波動（fluctuations in traffic）、程式錯誤（errors）、節點當機（node goes down）、以及進行更新（updates）時。
- **合理期望**：你不能期望 Pod 不死，但可以期望「**若 Pod 被拿掉，它應該要能自己回來**」——這正是後面 Deployment 要解決的問題。
- **工程鏡頭（failure mode）**：把 Pod 視為 cattle（牲口）而非 pet（寵物）——個體可拋棄、可替換，靠群體與控制器維持服務，而非呵護單一實例。

### 2. 裸 Pod 不夠可靠：刪了不會回來 [00:00:44–00:00:58]

**本段問題**：單獨建立的 Pod 有什麼致命缺陷？

- **示範現象**：若刪掉一個直接建立的裸 Pod，「that pod's going to get deleted, but it ain't coming back（它會被刪掉，但不會回來）」——**definitely not bulletproof（絕非打不死）**。
- **結論**：正因如此，**在生產環境幾乎不單獨建立 Pod（pods are rarely ever created on their own）**，而是「作為 Deployment 的一部分」被建立。
- **關聯**：這是全講的動機（why）——沒有控制器在背後盯著，Pod 的可靠度等於 0。

### 3. 建立第一個 Deployment：demo-deploy + nginx [00:00:58–00:01:32]

**本段問題**：怎麼用命令式方式快速建立一個 Deployment？

- **操作**：命令式建立一個名為 `demo-deploy` 的 Deployment，使用 `nginx` image（因為 nginx「簡單、好建」）。
- **觀察 1**：它「made a pod named after the deployment（造出一個以 Deployment 命名的 Pod）」——Pod 名繼承 Deployment 名。
- **觀察 2**：`kubectl get deploy`（或 `deployment`）會列出這個 Deployment，並顯示 **`1/1 ready`（一份中有一份就緒）**——READY 欄位是「就緒副本數 / 期望副本數」。
- **工程鏡頭（元件與職責）**：`kubectl create deployment` 是命令式捷徑，適合 demo / 探索；正式環境傾向宣告式 manifest（見 §6）。

### 4. replicas 與 kubectl scale：從 1 變 3 [00:01:32–00:02:17]

**本段問題**：Deployment 如何做出「多份一模一樣的 Pod」？

- **replicas 概念**：Deployment 能造出同一 Pod 的多個克隆，稱為 **replicas（副本）**。
- **操作**：`kubectl scale` 把 `demo-deploy` 的副本數從 1 改成 3——螢幕上「two more pods joining the battle（多兩個 Pod 加入戰局）」。
- **不變式（invariant）**：Deployment 會「ultimately make sure that there are three pods, no more, no less, constantly running（最終確保剛好三個 Pod 持續運行，不多不少）」。這句是理解整個 Deployment 模型的關鍵：它維持的是一個**恆定的副本數不變式**。
- **工程鏡頭（控制流）**：`scale` 改的是 desired state 的 `replicas` 值；控制器的 reconciliation loop 隨即把實際 Pod 數推向這個值。

### 5. 兩大好處：self-healing 與 scaling [00:02:17–00:02:54]

**本段問題**：把一堆 Pod「全部刪掉」會怎樣？

- **示範（self-healing）**：`kubectl delete pods --all` 把所有 Pod（含先前的 demo Pod）一次刪光——「**but look what happened, the deployment replaced them（但看發生什麼，Deployment 把它們全補回來了）**」。
- **歸納出兩大好處**：
  1. **Scaling（擴縮）**：可以 scale up（加 Pod）或 scale down（減 Pod），示範中又「take it back down to one（縮回一個）」。
  2. **Self-healing（自我修復）**：任何非預期死亡的 Pod，Deployment 都會確保它「come right back（立刻回來）」。
- **工程鏡頭（trade-off）**：self-healing 讓你獲得容錯與韌性，代價是你**失去對「特定那個 Pod 實例」的控制**——你管理的是「數量與樣板」，不是個體。

### 6. Deployment manifest 結構：兩層 metadata、兩層 spec [00:02:54–00:04:07]

**本段問題**：為什麼 Deployment 的 manifest 比 Pod manifest 長、且容易混淆？

- **痛點**：Deployment manifest「稍微比目前看過的長一點」，一開始最 tricky 的就是它的結構。
- **關鍵洞見**：Deployment manifest 內**嵌著一份 Pod manifest**。相對於裸 Pod manifest，Deployment 把「替 Pod 命名」那部分 metadata **拿掉**（因為 Pod 會以 Deployment 命名）。
- **兩層結構（極易混淆，務必分清）**：
  - **上層 `metadata` / `spec`**：屬於 **Deployment 本身**。
  - **下層 `template.metadata` / `template.spec`**：屬於 **它要造的 Pod**。
- **口訣**：「**Deployments make pods**」——所以 Deployment 的 manifest 裡自然包含「它要造的 Pod」的 manifest。
- **工程鏡頭（系統模型）**：把 Deployment manifest 讀成「一份關於『如何持續生產某種 Pod』的規格書」——上層描述生產策略（幾份、怎麼認領），下層（template）描述產品長相。

### 7. Deployment 的 labels（選用）、spec 與 replicas 欄位 [00:04:07–00:04:50]

**本段問題**：manifest 裡哪些是 Deployment 自己的設定？

- **Deployment 也能有 labels**：Kubernetes 中「任何東西都能有 label」，但 Deployment 自身的 label **非必要（not required）**，初學可先不管。
- **`spec`（Deployment 層）**：注意這是「spec for the deployment」，別跟底部的「spec for the pod」搞混。
- **`replicas` 欄位**：先前用 `kubectl scale` 調的副本數，其實可以**直接寫在 manifest 的 `spec.replicas`**；改完 manifest 執行 `kubectl apply`，就會把副本數調到指定值——與 `kubectl scale` 效果相同。
- **工程鏡頭（宣告式 vs 命令式）**：`scale` = 命令式一次性動作；`replicas` 寫進 manifest + `apply` = 宣告式、可進版控、可重現，是 GitOps / IaC 的基礎。

### 8. label selector：Deployment 如何「認領」Pod [00:04:50–00:05:36]

**本段問題**：Deployment 怎麼知道「哪些 Pod 是我的」？

- **核心機制**：呼應先前 label 的用途——「label 被 Kubernetes 中許多物件用來識別、存取其他資源」。Deployment 正是這樣運作。
- **selector 的宣告**：Deployment 在 `spec.selector.matchLabels` 說：「**所有帶 `app: nginx` 這個 label 的 Pod，都是我的（if you have that label, you belong to me）**」。（ASR 的「App Engine X」= `app: nginx`。）
- **語意**：任何帶有該 label 的 Pod，都被視為屬於這個 Deployment 管轄。
- **工程鏡頭（資料流 / 鬆耦合）**：selector 是 Kubernetes 的「以 label 為中心的鬆耦合綁定」——Deployment 不記硬指標到某個 Pod，而是用「條件查詢」動態認領一群 Pod。這同一機制之後也讓 Service 能對這群 Pod 做負載均衡（見 [[Lesson_9_Kubernetes_Services]]）。

### 9. template：Pod 樣板與「label 必須一致」的鐵律 [00:05:36–00:06:04]

**本段問題**：Deployment 造 Pod 時的樣板長怎樣？為什麼 template 裡也要放 label？

- **template 的角色**：`spec.template` 描述「這個 Deployment 要造出的 Pod 的樣板」。
- **鐵律**：template 內必須替 Pod 打上 selector 認領的那個 label（`app: nginx`）——「**否則造出來的 Pod 連 Deployment 自己都認不得（won't even be recognized by the deployment itself）**」。
- **一致性要求**：`spec.selector.matchLabels` 與 `spec.template.metadata.labels` **必須匹配**，這是 Deployment 能運作的前提。
- **常見錯誤預告**：兩者不一致是新手最常見的 manifest 錯誤之一（見 §常見誤解）。

### 10. 從 manifest 建立：3 個 Pod 與 `get pods -l` [00:06:04–00:06:41]

**本段問題**：用 manifest 建立後如何在命令列驗證？

- **操作**：`kubectl create -f <manifest>`（或 `apply`）建立 Deployment，因為 `replicas: 3`，**立刻起了 1、2、3 三個 Pod**。
- **驗證**：`kubectl get pods -l app=nginx`（`-l` = label 篩選）會列出這些 Pod，並顯示 `app=nginx` 這個 label 欄——確認它們確實都帶著被認領的 label。
- **工程鏡頭（可觀測性）**：`-l`（`--selector`）是用 label 過濾資源的通用手法；同一 selector 思維貫穿 get / delete / Service / NetworkPolicy 等。

### 11. self-healing 實證：改 replicas、移除 label 觸發重建 [00:06:41–00:08:05]

**本段問題**：Deployment 如何忠實維持副本數？移除 Pod 的 label 會怎樣？

- **示範 A（改副本數）**：把 manifest 的 `replicas` 從 3 改成 2，`kubectl apply`，副本數就降為 2——與 `kubectl scale` 等效。
- **示範 B（移除 label，關鍵實驗）**：用 `kubectl label` 把某個 Pod 的 `app=nginx` label **拿掉**。結果：
  - Deployment **不會**去把失聯的 Pod 找回來。
  - 它認為「oh that pod's gone（那個 Pod 不見了）」，於是**新造一個 Pod 補足數量**。
  - 「the rule is always maintain this number, no more and no less（規則永遠是維持這個數字，不多不少）」。
- **可觀測細節**：Deployment 造的 Pod 名帶隨機字串以保證唯一——「a dead giveaway（一眼可辨）」它是被控制器造的。
- **工程鏡頭（控制流 / reconcile）**：Deployment 看的是「符合 selector 的 Pod 有幾個」，不是「特定實例還在不在」。移除 label = 讓那個 Pod 退出計數 → 實際數 < 期望數 → 補一個。這揭示 reconciliation 是「以集合計數為準」的。

### 12. 「打不死」的 Pod：只有刪 Deployment 或 scale 到 0 [00:08:05–00:08:50]

**本段問題**：怎樣才能真正清掉 Deployment 的所有 Pod？

- **示範 C（把 label 加回去）**：把剛移除的 label 貼回同一個 Pod。因為期望是 2 份、不多不少，系統最後「keeping the original pod（保留了原本那個 Pod）」——不會因此變成 3 份。
- **打不死（bulletproof）**：直接刪這些 Pod，它們「just going to keep coming back（一直回來）」。
- **唯二的清除方法**：
  1. **刪除 Deployment 本身**（`kubectl delete deployment ...`）——一刪，Pod 全消失。
  2. **把 `replicas` 縮到 0**。
- **工程鏡頭（生命週期）**：Pod 的生命週期被綁定在其擁有者（owner，即 ReplicaSet / Deployment）上；要停服務，操作的對象是控制器而非個別 Pod。

### 13. 真相揭露：Deployment 造的是 ReplicaSet，不是 Pod [00:08:50–00:10:13]

**本段問題**：「Deployment makes Pods」這句話哪裡不精確？

- **技術更正**：大家都說「deployments make pods」，但**技術上不精確**。真正造出 Pod 的是 **ReplicaSet（副本集）**。
- **ReplicaSet 是什麼**：比 Deployment 更古老的 Kubernetes 資源，「從一開始就存在」，職責是**維持固定數量的 Pod**。
- **ReplicaSet 的歷史痛點**：在生產環境「trying to swap them out was too much of a headache（要替換它們太麻煩）」——這是後來 Deployment 誕生的原因。
- **命名證據（naming as evidence）**：
  - ReplicaSet 以 **Deployment 名 + 自己的唯一字串** 命名。
  - Pod 又以 **ReplicaSet 名** 命名（共享同一段值）。
  - 因此從名字就能一眼看出「哪些 Pod 由哪個 ReplicaSet 所造」。
- **工程鏡頭（責任分層）**：Kubernetes 用「控制器堆疊」分離關注點——ReplicaSet 專責數量維持，Deployment 專責版本演進。

### 14. 三層責任鏈與 scheduler：Deployment → ReplicaSet → Pod → node [00:10:13–00:10:48]

**本段問題**：從 Deployment 到「Pod 落在哪台機器」的完整鏈路是什麼？

- **責任鏈**：`Deployment 造 ReplicaSet → ReplicaSet 造 Pod`。
- **scheduler 的角色**：Pod 要放到叢集內**哪個 node**，除非你另行指定，否則由 **scheduler（排程器）** 決定。
- **ReplicaSet 的態度**：只要要求的副本數存在，它對 Pod 落在哪個 node「happy to let them live and let live（隨遇而安）」。
- **工程鏡頭（控制平面分工）**：ReplicaSet 決定「要有幾個 Pod」（數量），scheduler 決定「每個 Pod 放哪」（放置）——兩個正交的決策由不同元件負責，可各自演進（nodeSelector / affinity / taint 等在此層介入）。

### 15. 為何用 Deployment 而非 ReplicaSet：版本控制 [00:10:48–00:11:40]

**本段問題**：既然 ReplicaSet 已在幹活，為何還要 Deployment？

- **the rub（癥結）**：Deployment 能做 ReplicaSet 能做的一切（因為它造 ReplicaSet），**額外還能做版本控制（version control）**。
- **版本控制能力**：
  - 對 Pod 的變更可以 **roll out（推出）與 roll back（回滾）**。
  - 且做到 **zero downtime（零停機）**——客戶端「never even notice that the pods got swapped out（根本不會察覺 Pod 被換掉）」。
- **關鍵性格差異**：對「其他類型物件」改 manifest 後推向執行中資源，「常常會報錯」；但 **Deployment「expect change / designed to make change（預期改變、為改變而生）」**。
- **工程鏡頭（CD / trade-off）**：Deployment 把「持續交付」內建為一級能力；代價是多一層抽象（多出 ReplicaSet 這層資源要理解與觀測）。

### 16. rolling update 機制：新 ReplicaSet + surge 逐一替換 [00:11:40–00:13:01]

**本段問題**：Deployment 更新時內部到底發生什麼？如何做到零停機？

- **不改舊的、另造新的**：當你要「根本性改變 Pod 的造法」，Deployment **不去修既有 ReplicaSet**，而是「creates a new replica set, a second one（建立第二個新的 ReplicaSet）」。
- **rolling update（預設策略）流程**（以期望 3 份為例）：
  1. **surge ahead one pod**：先加一個新版 Pod → 暫時變 4 個。
  2. **刪掉一個舊 Pod** → 回到 3 個。
  3. 再 surge 一個新的、再刪一個舊的……逐一替換。
  4. **不變式**：「at no time do we have less than the normal number of pods three（任何時刻都不會少於正常的三個）」。
- **零停機的代價**：更新過程中「可能有一瞬間你卡在兩個不同版本之間（split between two different versions）」——新舊版短暫並存；「有其他方法可繞開這點」（暗示 maxSurge/maxUnavailable 調參與其他策略）。
- **控制流（ASCII 重建，期望 3 份、maxSurge=1）**：

```
初始：  [old][old][old]                          (RS-A: 3, RS-B: 0)
surge： [old][old][old][NEW]                     (RS-A: 3, RS-B: 1)  ← 先加
汰換：  [old][old]     [NEW]                      (RS-A: 2, RS-B: 1)  ← 再刪
        [old][old]     [NEW][NEW]                (RS-A: 2, RS-B: 2)
        [old]          [NEW][NEW]                (RS-A: 1, RS-B: 2)
        [old]          [NEW][NEW][NEW]           (RS-A: 1, RS-B: 3)
完成：                 [NEW][NEW][NEW]           (RS-A: 0, RS-B: 3)
```

- **工程鏡頭（可用性不變式）**：rolling update 的本質是維持「可用副本數 ≥ 期望 − maxUnavailable」與「總副本數 ≤ 期望 + maxSurge」兩條不等式，在此約束下逐步遷移。

### 17. rollback：切回舊 ReplicaSet 就是反向 rolling update [00:13:01–00:13:40]

**本段問題**：更新出問題了怎麼退回去？

- **機制**：要從新版退回舊版，「All we have to do is have the deployment go back to using this replica set（讓 Deployment 改用回舊的 ReplicaSet）」。
- **過程**：「almost like this goes back in reverse（幾乎是反向重播）」——舊 ReplicaSet 這邊逐一加回 Pod，新 ReplicaSet 那邊逐一移除，直到回到「舊 RS 3 個、新 RS 0 個」。
- **能回滾的前提**：舊 ReplicaSet 並未被刪除，而是以**副本數 0 的形式保留**在旁，所以隨時能被重新拉回。
- **工程鏡頭（可逆性）**：rollback 與 rollout 是同一套 rolling 機制的兩個方向；保留舊 ReplicaSet = 保留「上一個已知良好狀態」，這是零停機可逆部署的基礎。

### 18. 實戰示範（上）：10 個 Pod、一個 ReplicaSet [00:13:40–00:14:06]

**本段問題**：大一點的規模看起來如何？

- **操作**：用 manifest 建立 `replicas: 10` 的 Deployment。
- **觀察**：它「immediately created a replica set（立刻造出一個 ReplicaSet）」——這是這個 Deployment「到目前為止的第一個、也是唯一一個 ReplicaSet」，底下掛著 10 個 Pod。
- **關聯**：接著要對這 10 個 Pod 做一次真實的變更，觀察第二個 ReplicaSet 誕生（§19）。

### 19. 實戰示範（中）：加一個 redis container 觸發滾動更新 [00:14:06–00:15:12]

**本段問題**：改變 Pod 內容（加一個 container）時，滾動更新怎麼跑？

- **變更內容**：讓這 10 個 Pod 從「1 個 container」變成「2 個 container」，加入一個 `redis` image（image 是什麼不重要，重點是示範）。
- **關鍵限制**：**「you cannot add new containers to pods that are already running（不能對執行中的 Pod 加新 container）」**——所以必須重建 Pod，正好演示 rolling update。
- **觀察（第二個 ReplicaSet 上線）**：
  - 「a second replica set appear（出現第二個 ReplicaSet）」。
  - 新 ReplicaSet 的可用 Pod 數**往上**、舊 ReplicaSet 的 Pod 數**往下**。
  - 「One is increasing, one is decreasing, effortlessly flowing from one to the next（一個增、一個減，順暢地從一邊流到另一邊）」→ Boom done。
- **結果**：10 個 Pod 全部重建，每個都含 2 個 container。
- **工程鏡頭（不可變基礎設施）**：Pod 一旦運行，其 container 組成不可原地變更——變更 = 造新 Pod 取代舊 Pod。這正是「immutable infrastructure（不可變基礎設施）」在 Kubernetes 的體現。

### 20. 實戰示範（下）：rollout history 與 rollout undo [00:15:12–00:16:33]

**本段問題**：如何查看部署歷史並一鍵回滾？

- **`kubectl rollout history <deployment>`**：查看這個 Deployment「經歷過幾個 revision（修訂版）」。
- **回滾**：講者先口誤說 `kubectl rollout history undo`，隨即更正為 **`kubectl rollout undo deployment demo-deploy`**（正確指令）：
  - 它會把「current revision（目前第 2 版）」退回「previous revision（前一版）」。
  - 之所以能秒退，是因為底層只是「從『10 個在新 RS』切回『10 個在舊 RS』」。
- **觀察**：數字開始切換，「rolling back one at a time（一次退一個）」——和當初 roll out 時「一次換一個」的節奏完全對稱。
- **課程收尾**：更多 `rollout` 進階用法（如指定回到特定 revision）留待完整課程。
- **工程鏡頭（運維手感）**：`rollout status` / `history` / `undo` 是日常排錯與救火的核心指令；配合 Probe（liveness/readiness）可讓 Kubernetes 自動判斷新版是否健康、要不要繼續推進。

## 🧪 例子、案例與應用

- **`kubectl create deployment demo-deploy --image=nginx`**：命令式起一個 Deployment，示範「Pod 名繼承 Deployment 名」與 `1/1 ready`。
- **`kubectl scale` 1→3**：示範副本數即時擴增與「不多不少」的副本不變式。
- **`kubectl delete pods --all` 後全被補回**：最直觀的 self-healing 證據。
- **移除單一 Pod 的 `app=nginx` label**：證明 Deployment 靠 label 計數認領——失聯即補新，不追回舊。
- **把 label 貼回**：證明既有 2 份已足額，系統保留原 Pod、不會超額。
- **replicas: 10 + 加 redis container**：真實規模下的 rolling update，第二個 ReplicaSet 上線、新增舊減。
- **`kubectl rollout undo`**：一鍵回滾到前一 revision，零停機、逐一替換。
- **應用場景**：無狀態 Web / API 服務（如 nginx 前端、REST 後端）的水平擴縮與持續交付；搭配 Service 對外提供穩定入口（見 [[Lesson_9_Kubernetes_Services]]）；在 GKE 上實作見 [[gke-deploy]] skill。

## ⚠️ 常見誤解與反例

- **誤解：Deployment 直接建立 Pod。**
  - **釐清**：Deployment 建立 **ReplicaSet**，由 ReplicaSet 建立 Pod（`Deployment → ReplicaSet → Pod`）。「Deployment makes Pods」只是口語簡化。
- **誤解：只要刪掉 Pod 就能把服務關掉。**
  - **釐清**：Deployment 的 Pod 打不死，會立刻重建；要清掉只能刪 Deployment 或把 `replicas` 設為 0。
- **誤解：`selector.matchLabels` 和 `template.metadata.labels` 可以不一樣。**
  - **釐清**：兩者必須匹配，否則造出的 Pod 不被 Deployment 認領，reconcile 會出錯或不斷造 Pod。這是新手最常見的 manifest 錯誤。
- **誤解：移除 Pod 的 label 後，Deployment 會把那個 Pod「找回來」重新貼標。**
  - **釐清**：它不追回失聯 Pod，只補一個**新的**以維持計數；失聯的舊 Pod 變成不受管理的孤兒 Pod（orphan）。
- **誤解：rolling update 過程中服務會短暫中斷。**
  - **釐清**：預設策略「先加後刪」，可用副本數任何時刻都不低於期望值，達零停機；但更新期間新舊版會短暫並存（需自行處理相容性）。
- **誤解：可以對執行中的 Pod 直接加一個 container。**
  - **釐清**：不行。變更 Pod 組成必須重建 Pod（不可變基礎設施），這正是 rolling update 介入的時機。
- **誤解：回滾會遺失或需重建舊版。**
  - **釐清**：舊 ReplicaSet 以副本數 0 保留，回滾只是把它重新拉回，等同反向 rolling update。

## 🧠 深層理解

1. **核心直覺是什麼？** Deployment 是一個「宣告式的期望狀態 + 持續調節迴圈」系統：你只描述「終點」（幾份、什麼樣、怎麼認領），系統負責永無止境地把「現實」推向那個終點。你管理的是**意圖**，不是**動作**。
2. **它解決了什麼問題？** 裸 Pod 不可靠（死了不回來）、手動維持副本數與手動更新易錯且有停機風險。Deployment 用 self-healing 解決可靠性、用 rolling update / rollback 解決零停機的持續交付。
3. **它犧牲或忽略了什麼？** 你失去對「特定 Pod 實例」的掌控（個體可被隨時替換），也不適合**有狀態、有身分**的工作負載（那需要 StatefulSet）。多了一層 ReplicaSet 抽象，觀測與除錯的心智負擔增加。
4. **它和哪些概念容易混淆？** 與 ReplicaSet（只管數量、無版本控制）、與 Service（負責網路入口與負載均衡，不造 Pod）、與 StatefulSet（有序、有身分、有持久儲存）容易混。selector 的 label 與 template 的 label 也常被搞混成同一層。
5. **教給初學者的比喻是什麼？** Deployment 像一位「工廠領班」：你交給他一張規格書（要 3 個一模一樣的產品、長這樣、貼這個標籤）。任何一個產品壞掉他就補一個新的；要改款時他不拆舊產線，而是另開一條新產線，一邊做新款一邊撤舊款，客戶完全不斷貨；發現新款有問題，他還能把舊產線重新開回來。
6. **現實使用的最大限制是什麼？** Deployment 假設 Pod 是**無狀態、可互換**的；對需要穩定網路身分或持久磁碟的服務（資料庫、訊息佇列）並不適用。此外，「零停機」只在應用本身能容忍新舊版並存、且正確設定 readiness probe 時才真正成立。

## 🕒 時間軸索引（Timeline Index）

- 00:00:00–00:00:44：Pod 的暫時性——所有 Pod 都會死，且不該預期永存
- 00:00:44–00:00:58：裸 Pod 不可靠（刪了不回來）→ 生產環境用 Deployment
- 00:00:58–00:01:32：建立 demo-deploy（nginx）、Pod 繼承 Deployment 名、`1/1 ready`
- 00:01:32–00:02:17：replicas 與 `kubectl scale` 1→3、「不多不少」不變式
- 00:02:17–00:02:54：delete pods --all 全被補回 → self-healing 與 scaling 兩大好處
- 00:02:54–00:04:07：Deployment manifest 結構、兩層 metadata（deployment vs pod）
- 00:04:07–00:04:50：Deployment 的 label（選用）、spec、`replicas` 寫進 manifest
- 00:04:50–00:05:36：label selector（`app: nginx`）——「帶此 label 者屬於我」
- 00:05:36–00:06:04：template 樣板與「label 必須一致」鐵律
- 00:06:04–00:06:41：從 manifest 建立、3 個 Pod、`get pods -l`
- 00:06:41–00:08:05：改 replicas 3→2；移除 label 觸發重建
- 00:08:05–00:08:50：貼回 label；打不死的 Pod；刪 Deployment 或 scale 到 0
- 00:08:50–00:10:13：真相——Deployment 造 ReplicaSet；命名證據
- 00:10:13–00:10:48：三層責任鏈與 scheduler 的角色
- 00:10:48–00:11:40：為何用 Deployment——版本控制、零停機、「為改變而生」
- 00:11:40–00:13:01：rolling update 機制（新 ReplicaSet、surge 逐一替換）
- 00:13:01–00:13:40：rollback——切回舊 ReplicaSet、反向重播
- 00:13:40–00:14:06：實戰——10 個 Pod、一個 ReplicaSet
- 00:14:06–00:15:12：加 redis container、第二個 ReplicaSet、新增舊減
- 00:15:12–00:16:33：`kubectl rollout history` 與 `rollout undo` 回滾

## 💻 實作範例（YAML manifest 與 kubectl 指令）

> 以下 manifest 依講解重建，欄位為 Kubernetes 標準寫法（逐字稿為投影片示範，實際欄位以官方 API 為準）。

### (1) 命令式快速起一個 Deployment（對應 §3–§5）

```bash
# 建立名為 demo-deploy 的 Deployment，使用 nginx image（Pod 名會以 deployment 命名）
kubectl create deployment demo-deploy --image=nginx

# 查看 Deployment 狀態（READY 欄顯示 就緒數/期望數，例如 1/1）
kubectl get deploy            # deploy 為 deployment 縮寫

# 擴縮：把副本數從 1 調到 3
kubectl scale deployment demo-deploy --replicas=3

# self-healing 示範：刪光所有 Pod，Deployment 會立即補回
kubectl delete pods --all
kubectl get pods              # 觀察 Pod 被重新建立

# 縮回 1 份
kubectl scale deployment demo-deploy --replicas=1
```

### (2) 宣告式 Deployment manifest（對應 §6–§10）

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:                       # ← 這一層 metadata 屬於「Deployment 本身」
  name: nginx-deployment
  labels:                       # Deployment 自身的 label（選用，非必要）
    app: nginx
spec:                           # ← 這一層 spec 屬於「Deployment 本身」
  replicas: 3                   # 期望副本數；等同 kubectl scale 的效果
  selector:
    matchLabels:
      app: nginx                # 認領條件：帶此 label 的 Pod 都屬於我
  template:                     # ← template 以下描述「要造出的 Pod」
    metadata:
      labels:
        app: nginx              # 必須與 selector.matchLabels 一致，否則 Pod 不被認領
    spec:                       # ← 這是「Pod 的 spec」
      containers:
        - name: nginx
          image: nginx:1.25     # 建議指定明確 tag，避免 latest 造成不可重現
          ports:
            - containerPort: 80
```

```bash
# 建立 / 套用 manifest（宣告式；改 replicas 後再 apply 即可擴縮）
kubectl apply -f nginx-deployment.yaml

# 以 label 篩選查看被認領的 Pod（-l = --selector）
kubectl get pods -l app=nginx

# 觀察三層責任鏈：Deployment → ReplicaSet → Pod
kubectl get deploy,rs,pods
```

### (3) label 實驗與「打不死」的 Pod（對應 §11–§12）

```bash
# 移除某個 Pod 的認領 label → Deployment 認為它「不見了」，補一個新的
kubectl label pod <pod-name> app-           # 尾綴 - 表示移除該 label

# 把 label 貼回（既已足額則不會超額）
kubectl label pod <pod-name> app=nginx

# 真正清除的唯二方法：
kubectl delete deployment nginx-deployment   # (a) 刪除 Deployment
kubectl scale deployment nginx-deployment --replicas=0   # (b) 縮到 0
```

### (4) rolling update 與 rollback（對應 §16–§20）

```bash
# 觸發滾動更新：更新 image（會產生新的 ReplicaSet，逐一替換 Pod、零停機）
kubectl set image deployment/nginx-deployment nginx=nginx:1.26

# 即時觀察滾動更新進度
kubectl rollout status deployment/nginx-deployment
kubectl get rs                               # 可見新舊兩個 ReplicaSet（新增舊減）

# 查看修訂版歷史
kubectl rollout history deployment/nginx-deployment

# 一鍵回滾到前一 revision（本質＝切回舊 ReplicaSet，反向 rolling update）
kubectl rollout undo deployment/nginx-deployment

# 回滾到指定 revision
kubectl rollout undo deployment/nginx-deployment --to-revision=1
```

### (5) 微調滾動策略（對應 §16 的「其他方法可繞開」）

```yaml
spec:
  strategy:
    type: RollingUpdate         # 預設；另有 Recreate（先全砍再全建，會停機）
    rollingUpdate:
      maxSurge: 1               # 更新時最多可超出期望副本數的量（先加）
      maxUnavailable: 0         # 更新時最多可不可用的副本數（設 0 = 嚴格零停機）
```

## 🧩 跨領域連結

- **雲原生 ↔ 控制理論**：Deployment 的 desired-state + reconciliation loop 就是**回授控制系統**：`replicas` 是 setpoint（設定點），實際 Pod 數是 process variable，控制器持續修正誤差趨近 setpoint。
- **雲原生 ↔ 分散式系統**：self-healing 與副本維持對應**冗餘與容錯**；reconcile 需**冪等（idempotent）**才能安全重試（見 [[distributed-systems-advisor]] skill 與 MIT 6.824 的狀態機複製）。
- **雲原生 ↔ DevOps / SRE**：rolling update / rollback 是**持續交付（CD）與零停機部署**的教科書範例；readiness probe 決定新版是否被納入服務。
- **雲原生 ↔ 版本控制（Git）**：revision / rollout history / undo 幾乎是 Git 的 commit / log / revert 在部署層的鏡像。
- **雲原生 ↔ 不可變基礎設施**：「不能對執行中 Pod 加 container、只能重建」呼應 immutable infrastructure 與函數式的「不修改、只替換」哲學。
- **軟體工程 ↔ 生產線 / 精實製造**：rolling update 的「一邊生產新款、一邊撤下舊款、永不斷貨」對應精實生產的無停線換模（SMED）。

## 🔗 延伸學習路徑

- **下一步應學**：[[Lesson_9_Kubernetes_Services]]（用 label selector 對 Deployment 的 Pod 做穩定入口與負載均衡）；接著 ConfigMap / Secret（注入設定與機密）、Probe（liveness/readiness/startup 如何影響 rolling update）、HPA（依負載自動擴縮 replicas）。
- **對照學習**：ReplicaSet（理解 Deployment 底層）、StatefulSet（有狀態、有身分工作負載）、DaemonSet（每 node 一個）、Job / CronJob（批次 / 排程）。
- **推薦關鍵字**：`Deployment`、`ReplicaSet`、`rolling update`、`maxSurge` / `maxUnavailable`、`rollout undo`、`revisionHistoryLimit`、`Recreate strategy`、`readinessProbe`、`selector` vs `template labels`、`declarative apply`、`immutable infrastructure`。
- **相關資源 / 實作**：本 repo 的 [[gke-deploy]] skill（在 GKE 上實際部署 Deployment、排查 Pending / CrashLoopBackOff / ImagePullBackOff）；Kubernetes 官方文件 Deployments 章節；CKA / CKAD 認證的 Workloads & Scheduling 範圍。
- **在知識地圖中的位置**：本講是從「認識單一 Pod」邁向「以控制器規模化管理工作負載」的樞紐；掌握它，才能理解其上的 Service / Ingress（暴露）、ConfigMap / Secret（設定）、HPA（自動擴縮）如何協同組成一個可運維的雲原生應用。

> 校正說明（ASR 修正）：逐字稿為自動轉錄，且來源語言被誤標為 Chinese（實際內容為英文口語），本筆記已依 Kubernetes 標準術語校正明顯誤植：「cube control」→ `kubectl`；「App Engine X」→ label `app: nginx`；「Engine X」→ `nginx`；「replica set(s)」統一寫作 `ReplicaSet`；「demo deploy / demo deployment」統一為 Deployment 名稱示例 `demo-deploy`；「redis image」保留為 `redis`；講者將回滾指令口誤為「kubectl rollout history undo」，已依其當場更正校為正確的 `kubectl rollout undo`。逐字稿中無時間戳，`###` 小節時間標記與時間軸均對齊 SRT；YAML manifest 之精確欄位（如 `strategy.rollingUpdate`、`maxSurge`）為依講解重建的標準寫法，逐字稿僅口頭示範投影片、未逐字唸出欄位，未可靠還原處未予杜撰。
