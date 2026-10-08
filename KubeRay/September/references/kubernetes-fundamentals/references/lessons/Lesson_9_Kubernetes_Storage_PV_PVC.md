# Kubernetes FULL COURSE Part 9：Kubernetes 儲存 —— Persistent Volumes 與 Persistent Volume Claims

> 來源：YouTube 逐字稿 + SRT｜https://www.youtube.com/watch?v=4oiTq-DB6wg
> transcript_source: [[2025-08-08_4oiTq-DB6wg_Kubernetes-FULL-COURSE-Part-9-Kubernetes-Storage-–-Persistent-Volumes-&-Claims.txt]]
> 講者：Chad（CKA/CKAD 認證講師，20 年教學經驗）
> 時長：約 15:38（00:00:00–00:15:38，單一影片）
> 領域：資訊科學／雲原生（Cloud Native）／DevOps／軟體工程
> 難度：入門到中階（CKA/CKAD 基礎）
> 學習目標：建立「Pod 裡的容器如何安全地把資料存到容器外、且在 Pod 死掉後仍能存活」的完整心智模型——理解 storage-agnostic 設計、Storage Class → Persistent Volume（PV）→ Persistent Volume Claim（PVC）→ Pod volume mount 這條資料流，能親手寫出 PV/PVC/Pod 三份 manifest、用 `kubectl` 觀察 PV/PVC 綁定（bound）、並以「殺 Pod 再重建仍讀得到檔案」驗證資料持久化。

## 📌 一句話總覽

本講回答一個雲原生實務裡繞不開的問題：**容器（container）是「用完即丟、不該存狀態」的短命個體，那我們的資料要放在哪、怎麼在 Pod 死亡與重建之間活下來？** Chad 的答案是 Kubernetes 一套「storage-agnostic（儲存無關）」的解耦（decoupled）設計：不論你用 AWS、Azure、地端磁碟或本機節點，都走**同一條公式化的路徑**——先用 **Storage Class** 教叢集「這種儲存長什麼樣、怎麼處理」，再用 **Persistent Volume（PV）** 代表「一塊實際的儲存空間」，再用 **Persistent Volume Claim（PVC）** 代表「對這塊空間的存取權／申領」，最後把 PVC 當成一個 **volume** 掛（mount）進 Pod、再掛進容器裡的某個目錄。核心觀念是「**PVC 是鑰匙、PV 是置物櫃（locker），一對一的婚姻關係（monogamous）**」：一個 PVC 只綁定一個 PV。本講在整個 Kubernetes 課程體系中承接前面 [[Lesson_8_ConfigMaps_and_Secrets]] 的 volume 掛載機制（掛法幾乎一模一樣），並為後續 [[Lesson_10_StatefulSets]] 這類「有狀態工作負載」鋪路。它的工程價值在於：把「儲存」從「運算（compute，即 Pod）」中徹底抽離，讓兩者能各自獨立地建立、綁定、重建與遷移，這正是雲原生「無狀態運算 + 外部持久化」架構的地基。

## 🧭 知識地圖（Knowledge Map）

- **前置知識**：
  - 容器與 Pod 的基本觀念（Pod 是一組容器的最小部署單位）。
  - Deployment / ReplicaSet：多副本 Pod 彼此相同（identical）。
  - volume 掛載機制——本講直接沿用 [[Lesson_8_ConfigMaps_and_Secrets]] 的「先把物件當 volume 加到 Pod → 再把 volume mount 到容器目錄」兩步驟。
  - 基本 YAML 與 `kubectl apply / get / exec / delete`。
- **本集核心**：
  - storage-agnostic 設計哲學與「同一公式」。
  - **Storage Class**（教叢集認識某類儲存）。
  - **Persistent Volume（PV）**（代表實際儲存空間；`storageClassName` / `capacity` / `hostPath` / `accessModes`）。
  - **Persistent Volume Claim（PVC）**（代表存取權；靠相同 `storageClassName` 找到 PV；一對一綁定）。
  - PV/PVC **binding（綁定）** 與容量自動對齊（PVC 要 1Gi 卻拿到 2Gi）。
  - 把 PVC 當 **volume** 掛進 Pod，再 `volumeMounts` 到容器目錄。
  - **manual storage class + `hostPath`**：從某個 node 取一塊空間當 PV。
  - **`nodeSelector`**：強制把 Pod 排到指定 node。
  - **持久性驗證**：寫檔 → 殺 Pod → 重建 → 檔案還在 → 到 node 上找到實體檔。
- **後續會連到**：
  - [[Lesson_10_StatefulSets]]（有狀態應用、`volumeClaimTemplates` 為每個副本自動配一份 PVC）。
  - dynamic provisioning（用 Storage Class 自動生成 PV，而非本講的手動 PV）。
  - CSI（Container Storage Interface）driver、雲端 provisioner（AWS EBS、Azure Disk、GCE PD）。
  - reclaim policy（`Retain` / `Delete` / `Recycle`）、其他 access modes（`ReadWriteMany`、`ReadOnlyMany`、`ReadWriteOncePod`）。
  - node affinity / taints & tolerations（比 `nodeSelector` 更彈性的排程控制）。
- **可跨領域連結**：作業系統（檔案系統 mount point、bind mount、掛載目錄）、資料庫（有狀態服務為何需要持久卷）、分散式系統（運算與儲存分離、[[gke-deploy]] 在 GKE 上以 PVC 掛雲端磁碟）、[[distributed-systems-advisor]]（何時才真的需要有狀態的分散式儲存）。

## 🎯 核心重點（Core Takeaways）

- **容器不該存長期資料**：容器會頻繁死亡（die all the time）、是無狀態（stateless，逐字稿 ASR 誤作 "stainless"）且應保持精簡（small），因此不該把數 GB 資料塞進容器本身；資料必須存到容器外部——雲端、磁碟或節點上。
- **Kubernetes 是 storage-agnostic（儲存無關）的**：它不偏袒任何廠商（team AWS、team Azure、team whatever），只要你「教」它某種儲存怎麼用即可；不論底層是什麼，都遵循**完全相同的公式**：Storage Class → PV → PVC → mount 進 Pod。
- **Storage Class 是「教叢集認識儲存」的物件**：建立 Storage Class 後，那份「DNA」就進到叢集裡，叢集才有能力去劃分（allocate）一塊塊可保留給 Pod 使用的儲存空間；多數廠商都直接提供現成的 Storage Class manifest。
- **Persistent Volume（PV）代表「儲存本身」**：它是從儲存空間中切出來、被抽象化（abstracted）的一塊空間（例如 3GB 一塊）；同一個邏輯 PV，若底層換成 AWS 或 Azure，manifest 內容會**截然不同**（參數因廠商而異），這也是教學上最麻煩之處。
- **Kubernetes 一切高度解耦（decoupled）**：PV 只代表「儲存」，「存取」則由另一個獨立物件負責——這就是 PVC 存在的理由；運算（Pod）、儲存表述（PV）、存取申領（PVC）三者各自獨立。
- **Persistent Volume Claim（PVC）代表「存取」**：用「鑰匙與置物櫃」比喻——**PVC 是鑰匙、PV 是置物櫃**，兩者結為一對一的「一夫一妻（monogamous）」關係：**一個 PVC 綁定一個 PV**，不會有多個 PVC 同時掛到同一個 PV。
- **真正被掛進 Pod 的是 PVC，不是 PV**：Pod 把 PVC 當成一個 volume 掛上來；掛法與 [[Lesson_8_ConfigMaps_and_Secrets]] 完全相同——先把物件加成 Pod 的 volume，再把該 volume mount 到容器內某個目錄。
- **完整資料流（由容器往回追）**：容器內的 `mountPath` → volume → PVC → PV → 從儲存空間抽象出來的空間 → 被 Storage Class 教會的儲存 → 實體儲存；任何被寫進那個目錄的資料都會一路落到後端儲存。
- **同一份儲存可被多個 Pod 共用**：如同 ConfigMap 可掛到多個 Pod，儲存也可掛到多個容器；因為同一個 Deployment 底下的 Pod 彼此相同（identical），理應存取相同儲存，把它們都接到同一個 PVC 是完全可行且容易的。
- **manual storage class + `hostPath` 是最原始但完全有效的做法**：不依賴任何雲廠商，直接手動挑一個 node，從它上面用 `hostPath` 取一塊目錄當 PV；雖然原始（primitive），但「不論你用哪種儲存，最終都歸結到 Storage Class、PV、PVC 這三樣」。
- **`storageClassName` 是 PVC 找到 PV 的最簡匹配依據**：只要 PVC 與 PV 的 storage class 相同（外加相容的 access mode 與容量），就能綁定；還有更嚴格的綁定方式，但本講的簡單場景不需要。
- **`accessModes: ReadWriteOnce（RWO）`**：代表該卷同一時間只能被**單一 node** 以讀寫方式掛載（一次一個 node 在寫）；這是這類基礎儲存最常見的存取模式。
- **PV/PVC 綁定後容量會向上對齊**：PVC 只要求 1Gi，但因為對到的 PV 是 2Gi，綁定後實際拿到 2Gi——「剩下的 1Gi 難道要浪費嗎？不」，系統自動放大到可用容量。
- **`nodeSelector` 可強制 Pod 落在指定 node**：透過 `nodeSelector`（如比對 hostname = node1）把 Pod 釘在特定節點；但**只有在非用不可時才該這麼做**（because you should only be doing this when you have to）。
- **資料真的持久化的證明有兩層**：其一，`kubectl exec` 進 Pod 在 `/data` 寫 `proof.txt`，殺掉 Pod 再重建後檔案仍在；其二，`ssh` 到 node 的 `hostPath` 目錄，直接 `cat` 得出同一份檔案內容——證明資料存在「容器以外」的地方。

## 🔑 關鍵字與術語表（Keywords & Glossary）

| 術語 | 原文 / 符號 | 說明 |
|---|---|---|
| 儲存無關 | storage-agnostic | K8s 不綁定特定儲存後端；只要教它某類儲存怎麼用即可，流程一致 |
| 儲存類別 | Storage Class | 教叢集「某類儲存長什麼樣、怎麼建立與處理」的物件；PV 建立時以 `storageClassName` 引用 |
| 持久卷 | Persistent Volume, PV | 代表一塊實際／抽象化的儲存空間（叢集層級資源，非 namespace-scoped） |
| 持久卷宣告／申領 | Persistent Volume Claim, PVC | 代表「對某塊儲存的存取權／申領」；被掛進 Pod 的其實是它 |
| 綁定 | bound / binding | PV 與 PVC 配對成功、鎖定為一對一關係的狀態 |
| 一夫一妻關係 | monogamous relationship | 一個 PVC 只綁一個 PV，反之亦然（比喻） |
| 鑰匙／置物櫃 | key / locker | PVC＝鑰匙、PV＝置物櫃（Chad 的比喻） |
| 解耦 | decoupled | K8s 把儲存表述（PV）與存取（PVC）與運算（Pod）拆成獨立物件 |
| 手動儲存類別 | manual storage class | 不依賴雲廠商、手動挑 node 取空間的最簡 storage class |
| 主機路徑 | hostPath | PV 直接對應某個 node 上的目錄；寫進卷的資料實際落在該 node 目錄 |
| 容量 | capacity / `spec.capacity.storage` | PV 有多大（例：2Gi） |
| 要求容量 | requests / `resources.requests.storage` | PVC 想要多大（例：1Gi）；綁定後向上對齊到 PV 容量 |
| 存取模式 | accessModes | 卷可被如何掛載；本講用 `ReadWriteOnce` |
| 單節點讀寫 | ReadWriteOnce, RWO | 同一時間只能被單一 node 以讀寫掛載 |
| 卷 | volume | Pod 層級的儲存抽象；先加到 Pod，再 mount 到容器 |
| 卷掛載 | volumeMounts | 容器層級設定，把某 volume 掛到容器內某目錄（`mountPath`） |
| 掛載路徑 | mountPath | 容器內部用來存取該卷的目錄（本講為 `/data`） |
| 節點選擇器 | nodeSelector | 以 label 比對，強制 Pod 排到指定 node（本講比對 hostname=node1） |
| 節點 | node | 執行 Pod 的工作機（本講的儲存實體所在） |
| 文件分隔 | `---`（three dashes） | 一份 YAML 檔中用三個橫線分隔多份文件（document） |
| kubectl exec | `kubectl exec`（逐字稿作 "cube control exec"） | 進到執行中的 Pod／容器內執行指令 |
| 持久化 | persist / persistence | 資料在 Pod 生命週期之外仍存活 |
| 無狀態 | stateless（逐字稿 ASR 作 "stainless"） | 容器不保存狀態、可隨時被替換 |

## 📖 詳細筆記（Detailed Notes）

### 1. 問題設定：為什麼儲存很麻煩、容器不能自己存資料 [0:00:00–0:01:24]
**本段回答的問題**：Kubernetes 的儲存為何複雜？資料為什麼不能放在容器裡？

- **為何複雜（Why hard）**：每家公司、每個團隊想用的儲存方式都不同——儲存放在哪、是哪種儲存，眾說紛紜（"a big kerfuffle"）；而且 Kubernetes 這些年在儲存處理上經歷過很多變化。
- **好消息（統一模型）**：不論你用哪種儲存——AWS（只是舉例）或其他——都會遵循**完全相同的公式**。這是本講最重要的心錨：學會一次，到處適用。
- **容器不該存資料的三個工程理由**：
  - 容器**時常死亡**（die all the time）——生命週期短、可被隨時替換。
  - 容器是**無狀態的**（stateless；逐字稿 ASR 誤植為 "stainless/不鏽鋼"，依語意校正為 stateless）。
  - 容器應保持**精簡**（small）——不該把數 GB 資料塞進容器映像／可寫層。
- **結論**：資料必須存到**遠端**——雲端、磁碟或類似位置。因此我們要做的，是「在 Pod 內的容器」與「可能在雲端或磁碟上的儲存」之間**開一條路徑（chart a path）**。
- **工程鏡頭（trade-off）**：這其實是「運算與儲存分離」的雲原生原則——把易逝的運算（Pod）與需要壽命的資料（volume/PV）解耦，才能各自獨立擴縮、重建與遷移。

### 2. 儲存流程總覽：從 container 到 storage 的四段路徑 [0:01:24–0:01:51]
**本段回答的問題**：這條「路徑」由哪些元件串成？第一步是什麼？

- **流程（control flow）第一步**：**教你的叢集怎麼處理你要用的儲存**（teach your cluster how to handle the storage）。
- **storage-agnostic 的精神**：Kubernetes 是儲存無關的——它可以是 team AWS、team Azure、team 任何你想要的，**前提是你得教會它需要知道的事**。
- **教的手段**：建立一個叫 **Storage Class** 的物件（詳見第 3 節）。
- **元件與職責預告**：Storage Class（教叢集）→ Persistent Volume（代表儲存）→ Persistent Volume Claim（代表存取）→ 掛進 Pod。本段是整條資料流的「目錄頁」。

### 3. Storage Class：把儲存的「DNA」植入叢集 [0:01:51–0:02:11]
**本段回答的問題**：Storage Class 到底做什麼？建立它有什麼效果？

- **定義／職責**：Storage Class 是「教叢集認識某類儲存」的物件。一旦建立，那份「DNA」就進到你的叢集裡。
- **產生的能力**：有了它，你才**能開始劃分（allocate）一塊塊儲存空間**（chunks of storage space），這些空間可被保留（set aside）並專門給你的 Pod 及其容器使用。
- **實務便利**：多數 Storage Class 你可以直接找到現成的 manifest（whatever vendor you're using），不必自己從頭寫——這是好消息。
- **關聯**：Storage Class 是「劃分 PV」的前置條件；PV 的 `storageClassName` 欄位就指向它（第 9 節）。
- **工程鏡頭**：可把 Storage Class 視為「儲存驅動的設定樣板／provisioner 描述」——它定義「怎麼生產這種儲存」，而 PV 是「已生產出來的一塊實體」。

### 4. Persistent Volume（PV）：代表「儲存本身」 [0:02:11–0:02:52]
**本段回答的問題**：PV 是什麼？為什麼它會因廠商而長得不一樣？

- **定義／職責**：假設從雲端切出一塊 3GB 的空間要用，這塊空間就存放在一個叫 **Persistent Volume** 的物件裡。**PV 代表儲存本身（represent that storage itself）**。
  - （講者口誤把「教叢集怎麼建立某類儲存」也算到 PV 頭上；嚴格說「教叢集」是 Storage Class 的職責，PV 是「代表一塊已存在／已描述的儲存」。見「常見誤解」。）
- **因廠商而異**：你現在看到的這個「AWS 版 PV」，若改用 Azure 之類，manifest 會**完全不同**——因為各廠商的參數差異極大（parameters are so different from vendor to vendor），這讓教學很難一體適用。
- **抽象化**：PV 是「從儲存空間抽象出來的一塊空間」（abstracted space），把底層細節包起來，對上層呈現為「一塊容量」。
- **關聯**：PV 只解決「代表儲存」，還沒解決「怎麼存取」——下一節登場的 PVC 才管存取。

### 5. 解耦與 Persistent Volume Claim（PVC）：代表「存取」 [0:02:52–0:03:37]
**本段回答的問題**：有了 PV 就夠了嗎？PVC 為什麼必要？它和 PV 什麼關係？

- **「這樣就好了吧？不。」**：Kubernetes 一切高度**解耦（decoupled）**。PV 只代表儲存；我們還需要一個**代表「存取」**的物件——那就是 **Persistent Volume Claim（PVC）**。
- **鑰匙／置物櫃比喻**：**PVC 是鑰匙（key），PV 是置物櫃（locker）**。
- **一對一婚姻**：兩者結為一體，是**一夫一妻（monogamous）**關係——**一個 PVC 綁定一個 PV**；不會有多個 PVC 同時掛到同一個 PV，「它不是這樣運作的」。
- **真正被掛的是 PVC**：被當成 volume 掛（mount）進實際 Pod 的，是這個 **PVC**（而非 PV）。
- **掛載方式沿用舊課**：若你看過 [[Lesson_8_ConfigMaps_and_Secrets]] 中 volume 怎麼加，這裡是非常相似的流程。
- **工程鏡頭（為何解耦）**：PV（誰提供空間）與 PVC（誰要用空間）分離，讓「叢集管理員準備儲存」與「應用開發者申領儲存」成為兩個可獨立演進的角色與職責——這是 K8s 儲存 API 的設計核心。

### 6. 掛載兩步驟與完整資料流回顧 [0:03:37–0:04:39]
**本段回答的問題**：PVC 怎麼掛進 Pod？整條路徑由容器往回追是怎樣？

- **掛載兩步驟（與 ConfigMap/Secret 相同）**：
  1. 把 volume **加到 Pod**（add the volume to the pod）。
  2. 把該 volume **掛到容器內某個目錄**（mounted to a directory inside of the container）。
- **成果**：於是任何被 Pod 的容器存進這個目錄的東西，都進入了完整的儲存流程。
- **由容器往回追的完整鏈（data flow）**：
  ```
  容器內 mountPath（如 /data）
     └─ 對應到 volume
          └─ volume 代表 PVC（Persistent Volume Claim）
               └─ PVC 連到 PV（Persistent Volume）
                    └─ PV 是從「儲存空間」抽象出來的一塊空間
                         └─ 這塊儲存被 Kubernetes 認得，因為你用 Storage Class 教過它
                              └─ 實體儲存（雲端／磁碟／node）
  ```
- **一句總結**：「這就是你存東西的方式（that's how you store your stuff）。」
- **關聯**：這條鏈是本講的骨架，後面 demo 每一步都在把某一環具體化。

### 7. 多 Pod 共享同一 PVC [0:04:43–0:05:22]
**本段回答的問題**：同一份儲存可以被多個 Pod／容器一起用嗎？為什麼合理？

- **可共享**：如同 ConfigMap 可掛到多個 Pod，**儲存也可掛到多個容器**。
- **為何合理**：如果這些 Pod 同屬一個 Deployment，它們彼此**相同（identical）**，因此理應存取**相同的儲存**；把它們都接到同一個 PVC 是完全可行、也很容易做到的。
- **限制／伏筆（本講未展開，但值得記）**：能否「多個 Pod 同時掛同一卷」其實受 `accessModes` 限制——本講示範用的是 `ReadWriteOnce`（同時間單一 node 讀寫）；真正的多節點共享需要 `ReadWriteMany`（見「延伸學習」）。講者此處著重「概念上可共享」。
- **工程鏡頭**：這對應「有狀態應用的共享資料」情境（如多副本讀取同一組設定或素材）；寫入衝突與一致性則是更進階的議題。

### 8. Demo 規劃：manual storage class 與整體劇本 [0:05:22–0:07:25]
**本段回答的問題**：接下來的實作要做什麼？為什麼選最原始的 manual storage class？

- **Demo 目標**：建立一個 PV、一個 PVC、一個掛載它的 Pod，並**親眼看到資料持久化**。
- **刻意「低技術」**：這是很 low-tech 的示範，但其中一切都是**最基本、不論用哪種儲存都適用**的原理；不偏袒任何廠商。
- **manual storage class 是什麼**：一種極簡的 storage class——**手動挑一個 node**（node1、node2 隨意），從它上面取一塊儲存空間當 PV。所以那「3GB」PV 是從某個 node 取來的。原始（primitive）但完全有效。
- **劇本步驟（control flow）**：
  1. 建 PV（從某 node 取空間）。
  2. 建對應的 PVC。
  3. 觀察兩者**綁定（bind together）**。
  4. 寫一份掛載該 PVC 的 Pod manifest。
  5. **刻意把 Pod 建在 node1 上**——順帶示範如何強制 Pod 落到特定 node。
  6. 因為 Pod 在 node1、PV 的儲存也取自 node1，最後會在 node1 的目錄裡找到我們寫的檔案。
- **預期驗證**：在 `mountPath`（data）裡建一個檔，該檔實際會**物理上位於 node1**；往回追應能在 node1 找到它（講者這裡先口誤說 `index.html`，實際 demo 寫的是 `proof.txt`）。

### 9. 撰寫 PV manifest：storageClassName / capacity / hostPath / accessModes [0:07:25–0:09:03]
**本段回答的問題**：PV 的 YAML 有哪些新欄位？各自什麼意思？

- **三份 manifest 放同一檔**：這次要寫三份 manifest，且全放在**同一份文件**裡（用 `---` 分隔，見第 10 節）。
- **PV 的 `spec` 新欄位**：
  - **`storageClassName`**：選擇「我用哪個 storage class 來建這個 PV」。**前提**：該 storage class 必須事先建立好。多數廠商都有現成 manifest。
  - **`capacity`**：這個 PV 有多大。
  - **`hostPath`**：因為這裡用的是本機（manual/local）儲存，`hostPath` 指定「node 上哪個目錄」作為取那幾 GB 空間的位置。換言之，任何存進這個 PV 的東西，都能在 node 的那個目錄裡找到。
  - **`accessModes`**：可設定的模式有好幾種；本講用 **`ReadWriteOnce`**——代表該卷同一時間只能被**單一 node** 以讀寫掛載（一次一個 node 在寫）。這是這類基礎儲存最常見的存取模式。
- **範例 PV manifest（依講述重建）**：
  ```yaml
  apiVersion: v1
  kind: PersistentVolume
  metadata:
    name: nginx-pv
  spec:
    storageClassName: manual          # 需事先建立好同名 StorageClass
    capacity:
      storage: 2Gi                    # PV 容量（demo 實際綁定顯示為 2Gi）
    accessModes:
      - ReadWriteOnce                 # RWO：同一時間單一 node 讀寫
    hostPath:
      path: /mnt/data                 # node 上的目錄；資料實體落於此
  ```

### 10. 撰寫 PVC manifest：靠相同 storage class 匹配 [0:09:03–0:09:55]
**本段回答的問題**：PVC 怎麼寫？它靠什麼找到並綁定 PV？

- **`---` 分隔多文件**：想在同一份 manifest 檔裡加另一份文件，YAML 用**三個橫線 `---`** 來分隔一份文件與另一份。
- **PVC 綁定 PV 的最簡條件**：這個 PVC 要找到那個 PV，**唯一需要的就是它們有相同的 storage class**。還有其他方式可保證兩者連上，但本講場景不需要。
- **其餘欄位**：
  - **相同的 access mode**（與 PV 相容）。
  - **要求容量**：這裡「把該 PV 可用的儲存全用掉」。
- **範例 PVC manifest（依講述重建）**：
  ```yaml
  ---
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: nginx-pvc                   # 後面 Pod 會用這個名字引用
  spec:
    storageClassName: manual          # 與 PV 相同 → 據此綁定
    accessModes:
      - ReadWriteOnce                 # 與 PV 相容
    resources:
      requests:
        storage: 1Gi                  # 要求 1Gi；因 PV 為 2Gi，綁定後拿到 2Gi
  ```
- **提醒**：實務上有遠比這複雜的 PV/PVC（full course 有深入），這裡為基礎課刻意保持極簡。

### 11. 撰寫 Pod manifest：volume + volumeMounts + nodeSelector [0:09:55–0:12:20]
**本段回答的問題**：Pod 怎麼把 PVC 掛進來？怎麼強制它落到 node1？

- **掛載兩步驟（重申，與 ConfigMap/Secret 相同）**：
  1. **先把物件當 volume 加到 Pod**：在 `volumes` 底下，宣告我要用名為 `nginx-pvc` 的 PVC（就是第 10 節那個 PVC 的名字），把它掛成 Pod 的一個 volume，取名 `nginx-pv-storage`。
  2. **再把 volume 加到容器**：在容器裡加 `volumeMounts`，其 `name` 要對上上面那個 volume 名，並挑一個容器內目錄當存取點（本講用 `/data`）。
- **往回追一次**：進到 `/data` → 就是 PVC → 就是 PV → 就是 node；因此**任何寫進這個目錄的東西都會寫到 node 上**。
- **`nodeSelector`（強制排程）**：
  - 有好幾種方法可強制 Pod 落到特定 node；**但你只有在非用不可時才該這麼做**（should only be doing this when you have to）。
  - 這裡的意思是「只落在 hostname 為 node1 的 node 上」，顯然會把 Pod 放到 node1。
  - **縮排坑**：`nodeSelector` 必須放在 `spec` 底下，和 `containers` 的 `c` 對齊；講者當場踩到縮排錯誤（"did not indent that properly / oopsie-daisy"）——YAML 對縮排極敏感，是最常見的 manifest 錯誤來源。
- **範例 Pod manifest（依講述重建）**：
  ```yaml
  ---
  apiVersion: v1
  kind: Pod
  metadata:
    name: nginx
  spec:
    containers:
      - name: nginx
        image: nginx
        volumeMounts:
          - name: nginx-pv-storage    # 對上下方 volumes 的 name
            mountPath: /data          # 容器內存取點
    volumes:
      - name: nginx-pv-storage
        persistentVolumeClaim:
          claimName: nginx-pvc        # 引用第 10 節的 PVC
    nodeSelector:                     # 與 containers 同層，位於 spec 底下
      kubernetes.io/hostname: node1   # 只排到 hostname=node1 的節點
  ```
- **套用**：`kubectl apply -f <file>.yaml`（一次套用含 `---` 分隔的三份文件）。

### 12. 觀察綁定（bound）與容量自動放大 [0:12:20–0:13:10]
**本段回答的問題**：套用後怎麼確認綁定成功？為什麼要 1Gi 卻拿到 2Gi？

- **一建立就綁定**：套用當下即可看到——**PVC 已 bound**，且綁到我們的 PV（講者澄清語序：是 PV 被綁到 PVC / PVC 被綁到 PV，互為綁定）。一切如預期。
- **驗證指令（依情境）**：
  ```bash
  kubectl get pv        # STATUS 欄應為 Bound
  kubectl get pvc       # STATUS 欄應為 Bound，CAPACITY 顯示實際容量
  ```
- **容量自動對齊**：PVC 明明要求 1Gi，結果卻是 **2Gi**——為什麼？因為對到的 **PV 就是 2Gi**；「難道剩下 1Gi 要浪費嗎？不」，系統自動放大到 PV 的可用容量。
- **工程鏡頭（trade-off）**：`requests.storage` 是「最少要這麼多」，綁定到更大的 PV 時會拿到整塊——因此手動 PV 場景下，PVC 的容量請求偏向「下限」而非「精確配額」；dynamic provisioning 才會精確依請求量生卷。

### 13. 驗證持久性（上）：寫檔 → 殺 Pod → 重建 → 檔案還在 [0:13:10–0:14:39]
**本段回答的問題**：怎麼證明資料真的「持久」？

- **進 Pod 看目錄**：用 `kubectl exec`（逐字稿作 "cube control exec"）進到 Pod，去 `/data` 目錄看看。
  - **第一個證據**：`/data` 目錄**存在**這件事本身，就代表 volume mount 確實生效了。
- **寫入測試檔**：`echo` 一句「help, I'm trapped in a file and I can't get out」寫進一個叫 `proof.txt` 的檔。
  ```bash
  kubectl exec -it nginx -- sh
  # 於容器內：
  echo "help, I'm trapped in a file and I can't get out" > /data/proof.txt
  exit
  ```
- **持久性驗證流程（control flow）**：
  1. **殺掉所有相關 Pod**（"kill all these pods"；先前有跑過 Deployment，那個掛了儲存的 Pod 現在死了）。
  2. **重建 Pod**（rebuild that pod again）。
  3. **再進 Pod**、看 `/data` 裡還有沒有 `proof.txt`。
  4. **結果：有！** —— 這就是資料正在持久化的證明。「我們正在使用儲存。」
- **關鍵洞見**：Pod 死亡並重建後檔案仍在，證明資料**不在容器裡**，而在容器生命週期之外的地方（PV → node）。這正是 PV/PVC 存在的全部意義。

### 14. 驗證持久性（下）：到 node 上找到 hostPath 實體檔 [0:14:39–0:15:38]
**本段回答的問題**：資料到底實際落在哪？如何眼見為憑？

- **Pod 在哪個 node**：因為 `nodeSelector` 指定 node1，這個 Pod 就在 **node1** 上。
- **直接 ssh 進 node1 找實體檔**：
  ```bash
  ssh node1
  cd /mnt/data          # 即 PV 的 hostPath 目錄
  ls                    # 赫然看到 proof.txt
  cat proof.txt         # 印出：help, I'm trapped in a file and I can't get out
  ```
- **意義**：`hostPath` 目錄裡「果然」（lo and behold）有 `proof.txt`，`cat` 出來就是我們寫的那句話——證明**資料持久在「容器以外」的位置**（node 的檔案系統）。
- **全講總結**：這雖是很原始（primitive）的儲存形式，但**不論你用哪種儲存，最終都歸結到這三樣：Storage Classes、Persistent Volumes、Persistent Volume Claims。**

## 🧪 例子、案例與應用

- **鑰匙與置物櫃（key & locker）**：說明 PVC↔PV 的一對一綁定——一支鑰匙開一個櫃子，不會多支鑰匙共開一櫃。幫助記住 `binding` 的排他性與 `monogamous` 語意。
- **manual storage class + hostPath demo**：不需任何雲帳號即可完整走完 Storage Class → PV → PVC → Pod → 持久化的閉環；適合本機（minikube/kubeadm 多節點）練習 CKA/CKAD 基礎。
- **殺 Pod 再重建仍讀得到 `proof.txt`**：最直觀的「持久化」驗收案例；可延伸為資料庫 Pod 重啟後資料不遺失的心智模型。
- **同一 Deployment 多 Pod 共享儲存**：對應「多副本讀取同一組共享資料」的實務（本講以 `ReadWriteOnce` 展示概念；真正多節點寫入需 `ReadWriteMany`）。
- **`nodeSelector` 釘住 node1**：對應「Pod 必須跑在有特定硬體／本機磁碟的節點」情境，例如本機 `hostPath` 卷只存在於某節點時，Pod 就得排到該節點。

## ⚠️ 常見誤解與反例

- **誤解：是 PV 在「教叢集怎麼建立儲存」。**
  - **釐清**：講者口語上把這句掛到 PV 頭上，但嚴格的 K8s 模型是——**Storage Class** 負責「教叢集怎麼 provision 這類儲存」，**PV** 是「代表一塊實際／已描述的儲存」。記憶法：Storage Class = 藍圖／配方，PV = 依配方產出的一塊實體，PVC = 對那塊實體的申領。
- **誤解：被掛進 Pod 的是 PV。**
  - **釐清**：被當成 volume 掛進 Pod 的是 **PVC**，不是 PV。Pod 永遠透過 PVC 間接使用 PV。
- **誤解：多個 PVC 可以共用同一個 PV。**
  - **釐清**：不行。**一個 PVC 綁一個 PV**（一夫一妻）。至於「多個 Pod 共用儲存」，是多個 Pod 掛**同一個 PVC**，而不是多個 PVC 掛同一個 PV。
- **誤解：`ReadWriteOnce` 代表「只能一個 Pod 掛」。**
  - **釐清**：RWO 的粒度是 **node**——「同一時間單一 node 以讀寫掛載」。同一 node 上的多個 Pod 仍可能共用；跨 node 才受限。（想要每個 Pod 獨佔需 `ReadWriteOncePod`；想多節點讀寫需 `ReadWriteMany`。）
- **誤解：PVC 要 1Gi 就只會拿到 1Gi。**
  - **釐清**：`requests.storage` 是**下限**。綁到 2Gi 的 PV 時會拿到整塊 2Gi。精確依量配置是 dynamic provisioning 的行為，不是靜態 PV 綁定的行為。
- **誤解：`hostPath` 適合正式生產環境。**
  - **釐清**：`hostPath` 把資料綁死在單一 node 上，該 node 掛掉資料就存取不到，且需 `nodeSelector` 把 Pod 釘住——這是**教學／單機**用的原始做法。生產應改用雲端磁碟／網路儲存（透過 CSI provisioner + dynamic Storage Class）。
- **誤解：`nodeSelector` 是常規做法。**
  - **釐清**：講者明說「只有在非用不可時才該用」；隨意釘住節點會削弱排程器的彈性與高可用。更彈性的替代是 node affinity / taints & tolerations。

## 🧠 深層理解

1. **核心直覺是什麼？** 把「容易死的運算」與「需要壽命的資料」拆開：Pod 可隨時死而重建，資料則活在 Pod 之外的 PV（最終落到磁碟／雲端／node）。PVC 是兩者之間可插拔的「存取契約」。
2. **它解決了什麼問題？** 容器無狀態、易逝、應精簡，卻又常常需要保存資料；PV/PVC 提供一套**廠商無關、可解耦、可重建**的持久化機制，讓資料在 Pod 生命週期之外存活。
3. **它犧牲或忽略了什麼？** 多了一層抽象與物件（Storage Class/PV/PVC）與綁定生命週期管理；靜態 PV 需人工預先配置；`hostPath`/RWO 場景犧牲了跨節點可用性與併發寫入；本講也未觸及 reclaim policy、資料備份與一致性。
4. **它和哪些概念容易混淆？** PV vs PVC（供給 vs 申領）、Storage Class vs PV（配方 vs 實體）、volume vs PVC（Pod 內抽象 vs 叢集資源）、`ReadWriteOnce` 的 node 粒度 vs Pod 粒度、`hostPath` vs 雲端持久磁碟。
5. **教給初學者的比喻是什麼？** Storage Class 是「置物櫃的規格書／製造配方」，PV 是「一個做好的置物櫃」，PVC 是「開那個櫃子的鑰匙」，Pod 拿著鑰匙把櫃子當成自己房間裡的一個抽屜（`mountPath`）來用。
6. **現實使用的最大限制是什麼？** 靜態手動 PV + `hostPath` 不具可攜性與高可用；正式環境幾乎都改用 **dynamic provisioning**（Storage Class 自動生 PV）搭配雲端／網路儲存，並要處理 access mode、reclaim policy、備份與跨區容錯。

## 🕒 時間軸索引（Timeline Index）

- 0:00:00–0:01:24：問題設定——儲存為何複雜、容器為何不能自己存資料（stateless、易逝、應精簡）
- 0:01:24–0:01:51：流程總覽——第一步「教叢集認識儲存」＝建立 Storage Class
- 0:01:51–0:02:11：Storage Class 把「DNA」植入叢集，才能劃分儲存空間
- 0:02:11–0:02:52：Persistent Volume（PV）代表儲存本身；因廠商而異
- 0:02:52–0:03:37：解耦與 PVC——鑰匙／置物櫃、一對一綁定
- 0:03:37–0:04:39：掛載兩步驟與「由容器往回追」的完整資料流
- 0:04:43–0:05:22：多個 Pod（同 Deployment）共享同一 PVC
- 0:05:22–0:07:25：Demo 規劃——manual storage class、整體劇本、預期驗證
- 0:07:25–0:09:03：PV manifest——`storageClassName` / `capacity` / `hostPath` / `accessModes(RWO)`
- 0:09:03–0:09:55：PVC manifest——`---` 分隔、以相同 storage class 綁定
- 0:09:55–0:12:20：Pod manifest——volume + volumeMounts(`/data`) + `nodeSelector`（縮排坑）
- 0:12:20–0:13:10：觀察 bound、容量從 1Gi 自動放大到 2Gi
- 0:13:10–0:14:39：持久性驗證（上）——寫 `proof.txt`、殺 Pod、重建、檔案仍在
- 0:14:39–0:15:38：持久性驗證（下）——ssh 進 node1 於 `hostPath` 找到實體檔；全講總結三元件

## 💡 重點問答 / 自我測驗

- **Q：為什麼不能把長期資料存在容器裡？（定義題）**
  A：容器時常死亡、是無狀態的、且應保持精簡；資料放容器內會隨容器消失，也違反容器「小而易逝」的設計，故須存到容器外部（雲端／磁碟／node）。
- **Q：storage-agnostic 是什麼意思？（概念題）**
  A：Kubernetes 不綁定特定儲存後端；不論 AWS、Azure、地端或本機，只要用 Storage Class 教會叢集，都走「Storage Class → PV → PVC → mount」同一條公式化流程。
- **Q：Storage Class、PV、PVC 三者的職責如何分工？（比較題）**
  A：Storage Class＝教叢集「某類儲存怎麼建立與處理」（配方）；PV＝代表一塊實際／抽象化的儲存空間（實體）；PVC＝代表對某塊儲存的存取權／申領（鑰匙）。
- **Q：被掛進 Pod 的是 PV 還是 PVC？（易錯題）**
  A：是 **PVC**。Pod 透過把 PVC 當 volume 掛入，間接使用其綁定的 PV。
- **Q：「鑰匙／置物櫃」比喻對應什麼技術事實？（推理題）**
  A：PVC＝鑰匙、PV＝置物櫃，兩者一對一綁定（monogamous）；一個 PVC 只綁一個 PV，不會多個 PVC 共綁同一 PV。
- **Q：PVC 靠什麼找到並綁定 PV？（應用題）**
  A：最簡條件是兩者有**相同的 `storageClassName`**，外加相容的 access mode 與容量；還有更嚴格的綁定方式但基礎場景不需要。
- **Q：`accessModes: ReadWriteOnce` 限制的粒度是 Pod 還是 node？（易錯題）**
  A：是 **node**——同一時間單一 node 可讀寫掛載。要 Pod 級獨佔用 `ReadWriteOncePod`，要多節點讀寫用 `ReadWriteMany`。
- **Q：PVC 要求 1Gi 卻拿到 2Gi，為什麼？（推理題）**
  A：因為綁定到的 PV 是 2Gi；`requests.storage` 是下限，綁到更大的 PV 就拿整塊，系統自動放大而不浪費。
- **Q：`hostPath` 在 manual storage class 裡代表什麼？（定義題）**
  A：PV 對應到某個 node 上的一個目錄；寫進該 PV 的資料實際會落在那個 node 的該目錄下。
- **Q：`nodeSelector` 有什麼作用？何時該用？（應用題）**
  A：以 label（如 hostname）比對，強制把 Pod 排到指定 node；講者強調只有在非用不可時才該用（例如本機 `hostPath` 卷只存在某節點）。
- **Q：如何用兩層證據證明資料真的持久？（反例／驗證題）**
  A：其一，`kubectl exec` 進 Pod 於 `/data` 寫 `proof.txt`，殺 Pod 再重建後檔案仍在；其二，ssh 到 node 的 `hostPath` 目錄直接 `cat` 得出同一內容——證明資料在容器以外。
- **Q：多個 Pod 共享儲存，是「多 PVC 綁同 PV」還是「多 Pod 掛同一 PVC」？（易錯題）**
  A：是**多個 Pod 掛同一個 PVC**；PVC 與 PV 仍是一對一。
- **Q：為什麼一份 manifest 檔可以放三個物件？（語法題）**
  A：YAML 用三個橫線 `---` 分隔同一檔中的多份文件，因此 PV、PVC、Pod 可寫在同一個 `.yaml` 檔中一起 `kubectl apply`。
- **Q：`nodeSelector` 為何常見排錯是縮排？（除錯題）**
  A：它必須位於 `spec` 底下、與 `containers` 同層對齊；YAML 對縮排極敏感，縮排錯會讓欄位掛錯層級或解析失敗（講者現場即踩到此坑）。
- **Q：為什麼生產環境不建議 `hostPath` + 手動 PV？（trade-off 題）**
  A：資料綁死在單一 node、該 node 故障即無法存取、缺乏可攜性與高可用；生產應改用 dynamic provisioning + 雲端／網路儲存。

## 🧩 跨領域連結

- **雲原生架構 ↔ 分散式系統**：PV/PVC 體現「運算與儲存分離」，與 [[distributed-systems-advisor]] 的「先問是否真需要有狀態／持久化，再引入複雜度」相呼應——不是每個服務都該掛持久卷。
- **Kubernetes ↔ 作業系統**：`volumeMounts` 的 `mountPath` 與 `hostPath` 直接對應 OS 的檔案系統掛載點與 bind mount；理解 mount 概念能秒懂容器內目錄如何對映到外部儲存。
- **PV/PVC ↔ 資料庫工程**：有狀態服務（DB、訊息佇列）為何需要持久卷、access mode 與備份策略如何影響資料安全，是本講概念的直接應用場景。
- **靜態 vs 動態配置 ↔ 資源管理／經濟學**：手動預配 PV（供給先行）vs dynamic provisioning（依申領即時生卷）＝「預先囤貨 vs 隨需生產」的資源配置取捨。
- **GKE 實務 ↔ 本講**：在 GKE 上把應用掛雲端磁碟（PD）通常透過 PVC + 雲端 Storage Class 的 dynamic provisioning——見 [[gke-deploy]] skill，把本講的本機 demo 對照到真實雲端部署。
- **access mode ↔ 併發控制**：`ReadWriteOnce` / `ReadWriteMany` 對應「單寫 vs 多寫」，與資料庫鎖／併發一致性的思路相通。

## 🔗 延伸學習路徑

- **下一步應學**：
  - **Dynamic provisioning**：用 Storage Class 自動生 PV，取代本講的手動 PV。
  - **[[Lesson_10_StatefulSets]]**：有狀態工作負載與 `volumeClaimTemplates`（為每個副本自動配 PVC）。
  - **其他 access modes**：`ReadWriteMany`（RWX）、`ReadOnlyMany`（ROX）、`ReadWriteOncePod`。
  - **Reclaim policy**：`Retain` / `Delete` / `Recycle`——PVC 刪除後 PV 與資料的去留。
  - **CSI（Container Storage Interface）** 與各雲 provisioner（AWS EBS、Azure Disk、GCE PD）。
  - **排程進階**：node affinity、taints & tolerations（比 `nodeSelector` 更彈性）。
- **推薦關鍵字**：`persistentVolume`, `persistentVolumeClaim`, `storageClass`, `hostPath`, `accessModes`, `ReadWriteOnce`, `volumeClaimTemplates`, `reclaimPolicy`, `dynamic provisioning`, `CSI driver`, `kubectl get pv/pvc`, `nodeSelector`。
- **相關資源**：Kubernetes 官方文件 Storage 章節（Persistent Volumes、Storage Classes、Volumes）；CKA/CKAD 考綱 Storage 領域；本 repo 的 [[gke-deploy]] skill（把 PV/PVC 概念落到 GKE）。
- **在知識地圖中的位置**：本講是「Kubernetes 儲存」的入門地基——上承 [[Lesson_8_ConfigMaps_and_Secrets]] 的 volume 掛載機制，下啟 [[Lesson_10_StatefulSets]] 與 dynamic provisioning／CSI 等進階儲存主題。

> 校正說明（ASR 修正）：逐字稿為自動轉錄（ASR 誤把語言標為 Chinese，實際內容為英文），本筆記已將明顯同音／誤植校正為標準術語——「stainless」→ **stateless（無狀態）**；「cube control exec」→ **`kubectl exec`**；「fivefold/類似音」未出現於本篇但依慣例處理同音詞；口語填充語（"oopsie-daisy"、"ducks in a row" 等）在教材中轉為技術敘述。講者對「PV 教叢集建立儲存」的口語表述略有鬆動，本筆記在「詳細筆記 §4」與「常見誤解」中標註並釐清為 Storage Class 的職責。示範中的容量數字依講者實述保留（介紹以 3GB 舉例、demo 綁定顯示 PV=2Gi / PVC 要求 1Gi）；`hostPath` 目錄與 PV/PVC/Pod 名稱（`/data`、`nginx-pvc`、`nginx-pv-storage` 等）依逐字稿還原，manifest 為依講述重建的最小可用範例，無法可靠還原的細節未予杜撰。
