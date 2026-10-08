# Kubernetes FULL COURSE：Lesson 1 — Kubernetes 架構（Kubernetes Architecture — How It Works & Why It Matters）

> 來源：逐字稿 + SRT（YouTube ASR）｜https://www.youtube.com/watch?v=KhI5vjxNVb4
> 講者：Chad（CKA/CKAD 認證講師，20 年教學經驗；Alta3 Academy）
> 時長：約 20 分鐘（00:00:00–00:20:11）
> 領域：資訊科學／雲原生（Cloud Native）／DevOps／分散式系統基礎
> 難度：入門到中階（CKA / CKAD 認證基礎，Part 1）
> 學習目標：建立「Kubernetes 是一個管理容器化應用的分散式控制系統」的整體心智模型——從「為什麼需要 Kubernetes」（容器化 + 微服務 + 自動化維運）出發，理解 Pod / Node / Cluster 的組成階層，再逐一拆解 controller node 上的五大控制平面元件（kube-apiserver、etcd、scheduler、controller-manager、kubelet）與 worker node 上的 container runtime，最後用「建立一個 Pod」的端到端控制流把所有元件串起來，作為後續實作（Deployment、Service、ConfigMap…）的地基。
> transcript_source: [[2025-08-08_KhI5vjxNVb4_Kubernetes-FULL-COURSE-Part-1-Kubernetes-Architecture-–-How-It-Works-&-Why-It-Ma.txt]]

## 📌 一句話總覽

本講是整套 Kubernetes 課程的奠基講（foundation），要回答三個由淺入深的問題：**為什麼要用 Kubernetes（why）→ Kubernetes 是什麼（what）→ 怎麼運作（how）**。講者刻意先講「why」：現代應用走 **microservices**、把程式與相依性打包進 **container**（容器易建立、易替換、可攜、可擴展），但容器「生來就會死」，且傳統上跑在單一 VM 上會遇到三個災難場景——**資源耗盡無法擴展、容器掛掉沒人重啟、VM 一死全部陪葬**。Kubernetes 正是為了自動化解決這些維運痛點而生。接著建立組成階層：容器被包進 **Pod**（Kubernetes 管理的最小單位），Pod 跑在 **Node**（虛擬機）上，多個 Node 聚合成 **Cluster**；Node 分成放應用的 **worker node** 與跑管理工具的 **controller node**。全講最核心的骨架是 controller node 上的控制平面五大元件：**kube-apiserver（唯一大門）、etcd（狀態儲存的大腦）、scheduler（決定 Pod 落點）、controller-manager（執法官 daemon 集合）、kubelet（每個 node 的手腳與耳目）**，加上 worker node 上真正建容器的 **container runtime（Docker / containerd）**。本講在知識體系中的位置是「總綱地圖」：後續每一講（Pod 實作、Deployment、Service、Ingress、儲存、排錯）都是把這張架構圖的某一格放大。它向上連到 [[distributed-systems-advisor]]（etcd 的強一致性、Raft）、向下連到容器與 Linux 基礎，橫向連到 [[gke-deploy]] 的雲端實務。

## 🧭 知識地圖（Knowledge Map）

- **前置知識**：容器（container）與映像檔（image）基本概念、Docker 基礎（有更好，沒有也能懂）、虛擬機（VM）概念、一點 HTTP / API / client-server 直覺、YAML 語法。
- **本集核心**：
  - 動機：microservices → container 的優勢（易建立、易替換、可攜「it worked on my computer」、可擴展）與宿命（容器會死、不永生）。
  - 傳統容器管理的三大 failure mode：host 資源耗盡無法 scale、容器死掉被忽略、VM 死亡連鎖全滅。
  - 組成階層：**Container ⊂ Pod ⊂ Node ⊂ Cluster**；Pod 是 Kubernetes 管理的最小單位（wrapper around containers）。
  - Node 兩種角色：**worker node**（跑 Pod）與 **controller node / control plane**（跑管理工具，不該亂放 Pod）。
  - 控制平面元件：**kube-apiserver**（所有溝通的唯一入口與協調中樞）、**etcd**（強一致分散式 key-value store，存整個叢集狀態）、**scheduler**（決定 Pod 排到哪個 node）、**controller-manager**（管理 namespace、RBAC、ReplicaSet 等多個 controller daemon）、**kubelet**（每個 node 的 agent，執行 runtime 指令並回報狀態）。
  - 資料平面：worker node 上的 **container runtime engine**（Docker / containerd）、**image**、**registry**。
  - 客戶端工具：**kubectl** CLI + **kubeconfig**（cluster 位址 + certificate/key 憑證）。
  - 控制流：`kubectl create pod` → API server → etcd → scheduler → API server → kubelet → runtime，全程「宣告式（declarative）+ 非同步 reconcile」。
- **後續會連到**：Pod / multi-container Pod、Deployment / ReplicaSet（replica 管理）、Service / Ingress（網路）、ConfigMap / Secret（設定）、PV / PVC（儲存）、namespace 與 RBAC / ServiceAccount、Job / CronJob、HPA（自動擴展）、probe（liveness/readiness）、Pod 故障排查（Pending / CrashLoopBackOff / ImagePullBackOff / OOMKilled）。
- **可跨領域連結**：分散式系統（etcd 的強一致性、consensus / Raft、狀態機複製，見 [[distributed-systems-advisor]]）、控制理論（controller 的 desired state vs current state 閉環回饋）、作業系統（container 的 namespace/cgroup 隔離、程序生命週期）、雲端平台（[[gke-deploy]] 的 GKE 託管控制平面）。

## 🎯 核心重點（Core Takeaways）

- **Kubernetes 的存在理由是「自動化容器維運」而非「取代 Docker」**：容器解決了打包與可攜（microservices），但無法自己處理擴展、自癒與跨機協調；Kubernetes 是一層編排（orchestration）控制系統，把這些維運工作自動化。
- **容器的三大優勢與一個宿命**：優勢是易 spin up、易替換更新、可攜（「it worked on my computer → then we'll ship your computer」）、可 scale 出任意副本；宿命是「容器不設計來永生」——會被你主動 tear down，也會意外死亡，這正是需要自動化管理的根本原因。
- **不用 Kubernetes 時，單 VM 跑容器有三個災難場景**：(1) host 資源耗盡、容器無法再擴展；(2) 容器死掉卻被忽略、沒有自動重啟；(3) VM 一旦掛掉，上面所有容器連鎖全滅且無機制救回。Kubernetes 對這三者都有答案（scheduling、self-healing、多節點容錯）。
- **Pod 是 Kubernetes 管理的最小單位，而非 container**：Pod 是「包在容器外面的 wrapper」；Kubernetes 只認 Pod、不直接管 container。把容器包成一個 Pod 單元，是為了讓調度與控制更容易。
- **組成階層是嚴格的包含關係**：container 住在 Pod 裡，Pod 跑在 Node（VM）上，多個 Node 聚合成 Cluster。加 Node 等於「指數級」增加可用資源池，讓大量 Pod 有地方跑。
- **Node 分兩種 flavor，職責不可混**：**worker node**（綠色）是絕大多數 Pod 落腳處；**controller node** 是控制平面工具的樞紐（hub），因為它「很忙、要管整個叢集」，所以不應隨意（willy-nilly）把應用 Pod 塞上去。
- **一切溝通都走 API——API server 是叢集唯一的大門**：所有動作（來自 kubectl 或內部元件）都以 request 送到 kube-apiserver，由它判定合法性、回應資料或採取動作；它也是唯一能跟 etcd 對話的元件，並負責與每個 node 溝通。這種「single front door」設計讓認證、授權、稽核有單一收斂點。
- **etcd 是叢集的大腦，存放全部狀態（state）**：它是第三方、早於 Kubernetes 就存在的「強一致分散式 key-value store」，記錄有幾個 node、有幾個 Pod、Pod 是否真的在跑或在報錯、Pod 之間能否互通等。**失去 etcd 等於對叢集做腦白質切除（lobotomy）**——所有運行狀態的紀錄都會消失，故必須極度謹慎保護（備份）。
- **scheduler 負責「Pod 放哪個 node」的決策**：像玩 Tetris，盡量讓 Pod 在各 node 間平均分布，同時遵守使用者或系統設下的規則（rules）。若 manifest 沒指定落點，就由 scheduler 決定。
- **controller-manager 是「執法官（sheriff）」，管理一堆 daemon**：它負責維持各種物件的期望行為，例如透過 **namespace** 追蹤物件、透過 **RBAC + ServiceAccount** 控制權限、透過 **replica** 維持 Pod 副本數。它是 Kubernetes「宣告式控制迴圈」的執行者。
- **kubelet 是每個 node 的眼睛、耳朵與手腳**：它存在於每個 node（包括 controller node），負責在該 node 上啟動／停止／重啟容器、接收來自 controller node 的指令、並持續回報狀態。kubelet 出問題，該 node 就等於失聯（它是 node 對叢集的唯一連線）。
- **Kubernetes 不自己建容器——真正動手的是 container runtime**：每個 node 上都裝有 container runtime engine（Docker、containerd 等），實際跑 `docker run` / `podman run` 這類指令的是 **kubelet**，而不是使用者。容器的生命週期（image → registry → 建容器）在 Kubernetes 裡完全照舊。
- **image 與 registry 的角色不變**：image 是「容器該怎麼建、裡面應用怎麼設定」的模板／樣板（picture/template），必須從某個儲存處——**registry**——拉取，registry 可設定成各種來源（Docker Hub、私有 registry 等）。
- **「建一個 Pod」是一條多方來回的非同步協調流程**：`kubectl create` → API server 驗證 → 寫入 etcd（回 HTTP 200）→ 回覆使用者「收到」→ 問 scheduler 落點 → 更新 etcd → API server 通知目標 node 的 kubelet → kubelet 呼叫 runtime 真正建容器 → kubelet 持續回報狀態給 API server → API server 寫回 etcd。**使用者收到「OK」時 Pod 其實還沒建好**（宣告式：先記錄期望狀態，再非同步收斂）。
- **先建 Pod 還是先建 container？答案明確：先 Pod、後 container**：kubelet 先建立 Pod 這個 wrapper，再在其中建立 container——不是雞生蛋的哲學問題。
- **理解架構本身就是排錯（troubleshooting）能力**：知道每個元件做什麼、彼此如何互動，才能在 Pod Pending、報錯、node 失聯時快速定位是 scheduler、kubelet、runtime、etcd 還是 API server 哪一環出問題。

## 🔑 關鍵字與術語表（Keywords & Glossary）

| 術語 | 原文 / 符號 | 說明 |
|---|---|---|
| Kubernetes | Kubernetes, K8s | 容器編排（orchestration）系統；自動化容器化應用的部署、擴展與維運 |
| 容器 | container | 把程式碼與其相依性打包在一起的隔離執行環境；易建立、可攜、可擴展 |
| 微服務 | microservices | 把應用拆成多個小型、獨立部署的服務，各自打包成容器的架構風格 |
| 映像檔 | image | 容器的模板／樣板，描述容器如何建立與內部應用如何設定 |
| 映像倉庫 | registry | 儲存並提供 image 拉取的地方（如 Docker Hub、私有 registry），可設定不同來源 |
| 容器執行引擎 | container runtime engine | 每個 node 上實際建立與執行容器的引擎（Docker、containerd、CRI-O 等） |
| Pod | Pod | Kubernetes 管理的最小單位；包住一或多個 container 的 wrapper |
| 節點 | Node | 執行 Pod 的虛擬機（或實體機）；資源的提供者 |
| 工作節點 | worker node | 跑絕大多數應用 Pod 的 node（講者以綠色標示） |
| 控制節點 / 控制平面 | controller node / control plane | 跑管理工具（API server、etcd、scheduler…）的 node，是叢集的樞紐 |
| 叢集 | cluster | 多個 node 聚合而成的資源集合體 |
| kubectl | kubectl（講者口語作 "cube control"） | 安裝在個人工作站的 CLI 工具，用來存取與操作叢集 |
| kubeconfig | kubeconfig（口語 "cube config"） | 與 kubectl 同機的設定檔，含 cluster 位址、certificate 與 key，用來認證身分 |
| API 伺服器 | kube-apiserver / API server | 叢集唯一入口；接收所有 request、驗證合法性、協調其他元件、唯一與 etcd 對話者 |
| 應用程式介面 | API | 元件間溝通的介面；Kubernetes 一切操作皆透過 API（類 HTTP request/response） |
| etcd | etcd | 強一致分散式 key-value store；儲存整個叢集的狀態（state） |
| 強一致性 | strongly consistent | 讀取一定拿到最新寫入結果的一致性等級（分散式系統概念） |
| 鍵值儲存 | key-value store | 以 key 對應 value 的資料儲存模型 |
| 狀態 | state | 叢集當前實況：有幾個 node、幾個 Pod、Pod 是否運行/報錯、能否互通等 |
| 排程器 | scheduler / kube-scheduler | 決定 Pod 該落在哪個 node 上，追求平均分布並遵守規則 |
| 控制器管理員 | controller-manager | 管理多個 controller daemon，維持物件期望狀態（replica、namespace、RBAC 等） |
| 守護程序 | daemon | 常駐背景程序；controller-manager 管理一群 daemon |
| kubelet | kubelet | 每個 node 上的 agent，執行 runtime 指令、接收 controller 指令、回報狀態 |
| 命名空間 | namespace | 在叢集中對物件做邏輯分組與隔離的機制 |
| 角色型存取控制 | RBAC, role based access control | 以角色控制誰能對哪些資源做什麼操作的授權機制 |
| 服務帳號 | ServiceAccount | 供 Pod / 程序使用的身分，連接到 RBAC 權限 |
| 副本 | replica | Pod 的複製份數；由 controller 追蹤與維持 |
| 資訊清單 | manifest | 描述期望狀態的宣告式文件（通常為 YAML），交給 Kubernetes 執行 |
| 宣告式 | declarative | 描述「想要的最終狀態」，由系統負責收斂，而非逐步下指令（命令式） |
| 憑證 / 金鑰 | certificate / key file | kubeconfig 中用來向叢集認證身分的檔案 |
| 東西向圖 | east-west diagram | 講者描述元件間橫向來回溝通所用的示意圖 |
| HTTP 200 | 200 OK | HTTP 成功狀態碼；講者以「thumbs up」比喻 etcd 回應成功 |
| CKA / CKAD | CKA, CKAD | Certified Kubernetes Administrator / Application Developer 認證 |
| 自癒 | self-healing | 系統自動偵測失效並重建資源的能力（Kubernetes 的核心價值之一） |

## 📖 詳細筆記（Detailed Notes）

### 1. 課程定位、講者背景與學習路徑 [0:00:00–0:01:42]
**本段回答的問題**：這門課要教什麼？該按什麼順序學？

- **定位**：這是一套「zero to hero」的 Kubernetes fundamentals 課程 Part 1，目標是打好通過 **CKA / CKAD** 認證所需的基礎，或單純讓你 proficient with Kubernetes。
- **講者**：Chad，CKA/CKAD 認證、20 年教育專業（強調是真實教室帶真實學生，內容經實戰「tested, bloodied and proven」）。附帶宣傳 Alta3 Academy 的完整課程（labs、mock exams）——屬行銷段落，知識價值低。
- **學習策略**：已有基礎者可用 description 的 timestamps 跳看；新手建議照順序學。
- **關聯**：本講先建立整張架構地圖，後續才進入實作，符合「先 why/what/how 再動手」的教學結構。

### 2. 為什麼要用 Kubernetes：microservices 與容器的動機 [0:01:42–0:03:20]
**本段回答的問題**：在講 what/how 之前，為什麼一開始就需要 Kubernetes？

- **核心命題**：Kubernetes 是為了「enabling a certain lifestyle in application deployment」——也就是一種現代化、自動化的應用部署與維運方式。
- **起點**：應用 = 程式碼（code）+ 執行所需的相依性（dependencies）。在 **microservices** 風格下，做法是把 code 與 dependencies 一起塞進一個隔離環境——**container**。
- **容器的優勢**：
  - **易 spin up**：快速啟動（有 Docker 經驗更好，沒有也不擋路）。
  - **易替換**：要更新／改動應用可「in a snap」完成。
  - **可攜（portability）**：對應那個老笑話「it worked on my computer → then we'll ship your computer」——只要在一個容器裡跑得起來，部署到別處也應該跑得起來。
  - **可擴展（scalable）**：能建立任意數量的副本（copies）。
- **關聯**：這四個優勢是「為什麼要容器化」；但容器本身不會自我管理，下一段揭露它的宿命與痛點。

### 3. 容器的宿命與傳統容器管理的三大災難場景 [0:03:20–0:04:50]
**本段回答的問題**：只有容器、沒有 Kubernetes 時會遇到什麼問題？

- **容器的宿命**：容器「not meant to hang around forever」——不論是你主動 tear down，還是意外掛掉，死亡是一種必然（inevitability）。雖然有手動處理方式，但很費工。
- **前提設定**：容器必須跑在既有環境上（如一台 **virtual machine, VM**），只要資源允許可在 VM 裡建任意多容器；但終究會到「VM is tapped（資源見底）」，而你還需要 scale out。
- **三大災難場景（failure modes）**：
  1. **host 資源耗盡**：host machine 沒有空間再放容器，容器無法擴展（expand）。
  2. **容器死掉被忽略**：容器 die 之後沒有機制自動重啟，得「work fairly hard」手動處理。（劇透：這正是 Kubernetes 能代勞的。）
  3. **VM 死亡連鎖全滅**：所有容器都跑在同一台 VM 上，VM 一死，上面所有容器陪葬，且沒有任何機制把它們救回。
- **收束**：Kubernetes 對這三者都有 answer——分別對應調度/擴展、self-healing、多節點容錯。
- **關聯**：這三個痛點是後續 Deployment（維持 replica）、多 node 叢集（容錯）、controller reconcile（自癒）的直接動機。

### 4. Pod：Kubernetes 管理的最小單位 [0:04:50–0:05:24]
**本段回答的問題**：Kubernetes 到底管什麼？為什麼不直接管容器？

- **關鍵轉折**：容器在 Kubernetes 裡的運作方式「完全照舊」（不論由 Docker 或其他工具建立），但——容器會被放進一個 Kubernetes 物件：**Pod**。
- **定義**：Pod 只是「包在容器外面的 wrapper（包裝）」。
- **關鍵原則**：**Kubernetes manages Pods, not containers**——Kubernetes 只認 Pod、不直接管 container。把容器與其包裝綁成一個單元（unit），是為了讓控制更容易。
- **限制/誤區**：初學者常把 Pod 誤當成「容器的別名」；實際上 Pod 是一層抽象，一個 Pod 可包含多個容器（本講先建立單一觀念，multi-container Pod 留待後續）。
- **關聯**：Pod 是後續所有工作負載物件（Deployment、ReplicaSet、Job…）的基本積木；「管 Pod 不管 container」是理解 replica、調度、自癒的前提。

### 5. Node 與 Cluster：worker node vs controller node [0:05:24–0:07:22]
**本段回答的問題**：Pod 跑在哪裡？叢集怎麼組成？兩種 node 各做什麼？

- **組成階層**：Pod + container 這個「package deal」仍需跑在某個環境上（傳統上是 VM）。在 Kubernetes 裡，加入的 VM 稱為 **Node**；可加入多個 node，等於「指數級（exponentially）」放大整個資源池，供大量 Pod 使用。多個 node 聚合起來就是 **Cluster**（叢集 = 資源的集合體）。
- **兩種 node flavor**：
  - **worker node（綠色）**：絕大多數 Pod 的落腳處。同一 node 上可有多個 Pod；不同 node 上 Pod 數量可不均（disproportionate）；node 大小可不同——大的能放 3 個 Pod、小的可能只放 1 個。
  - **controller node（控制節點）**：也是一台 VM，是「維持叢集運行所需所有工具的樞紐（hub）」。
- **重要規則**：不要 willy-nilly（隨便）把應用 Pod 塞到 controller node 上，因為它「很忙」——它的資源要留給管理叢集這件大事。
- **關聯**：worker/controller 的分工是整個控制平面（control plane）與資料平面（data plane）分離的體現；後續五大元件都住在 controller node。

### 6. kubectl 與 kubeconfig：與叢集溝通的入口 [0:07:22–0:09:35]
**本段回答的問題**：我人在筆電上，怎麼操作遠端的叢集？

- **kubectl**（講者口語 "cube control"，Kubernetes 愛把 "cube/kube" 放在所有東西前面）：安裝在**你個人工作站/筆電**上的 **CLI 工具**，讓你從自己的機器存取叢集。
- **連線路徑**：kubectl 透過連到 **controller node** 來操作叢集；所有 kubectl 的 request 都由 **API server** 接收。**一切溝通都走 API**（懂 HTTP/API 更好，不懂也不致命，後面會說明為何重要）。
- **kubeconfig**（口語 "cube config"）：與 kubectl 同一台機器上的設定檔，內容包括：
  - **cluster 的位址（location）**——要連到哪個叢集。
  - **certificate 與 key file**——位於你本機，用來**認證你是誰**、證明你有權跟該叢集對話。
- **安全直覺**：任何人都能裝 kubectl，是什麼阻止他連到全世界任意叢集？答案是「必須被 configure（設定憑證）才行」。沒有這份設定，kubectl 永遠無法運作。
- **關聯**：kubeconfig 的憑證機制是後續 RBAC / ServiceAccount 授權的入口；「一切走 API」呼應下一段 API server 的中樞地位。

### 7. kube-apiserver：叢集唯一的大門 [0:09:35–0:10:29]
**本段回答的問題**：API server 到底做什麼？為什麼所有東西都要經過它？

- **職責**：叢集內「所有動作（all action）都透過 API」，意即所有 request 都送到 **API server**，由它：
  1. 判定 request 是否 **valid（合法/授權）**。
  2. 依請求內容**採取動作或回傳資訊**（response）。
- **中樞地位**：
  - 它是回傳資訊給 kubectl 的那一端。
  - 它也主動 reach out、與叢集裡**每一個 node** 溝通（叢集可有多個 node/VM）。
  - 它是**唯一能跟 etcd 對話**的元件（下一段登場）。
- **設計含義（工程鏡頭）**：把所有互動收斂到單一「front door」，讓認證（authentication）、授權（authorization）、稽核（audit）與一致性控制都有唯一交會點——這是 Kubernetes 安全與一致性的基石。
- **關聯**：後續每一個控制流（建 Pod、擴展、刪除）都以 API server 為協調中心；它像交通樞紐，流量非常大（「quite popular」）。

### 8. etcd：叢集狀態的儲存與大腦 [0:10:29–0:11:46]
**本段回答的問題**：叢集怎麼記得自己現在的樣子？狀態存在哪？

- **身分**：etcd 是**第三方**、早在 Kubernetes 之前就存在的元件（非 Kubernetes 發明）。官方定義：一個「**strongly consistent distributed key-value store（強一致分散式鍵值儲存）**」，提供可靠方式儲存需被分散式系統/機器叢集存取的資料——這描述的正是 Kubernetes cluster。
- **角色**：etcd **儲存 state（狀態）**，一切關於資料的紀錄都在此，具體例如：
  - 有幾個 node 連到叢集？
  - 有幾個 Pod 在跑？它們是**真的在跑還是在報錯（erroring out）**？
  - Pod 之間能否互相溝通？……這些「寫在哪」的答案都是 etcd。
- **極度重要性**：**失去 etcd = 對叢集做 lobotomy（腦白質切除）**——你會失去對叢集內所有運行事物的所有追蹤。無論管理員或開發者都應對它「very respectful」（務必備份、謹慎保護）。
- **限制/誤區**：只有 API server 能碰 etcd（見上一段），其他元件不得直接讀寫——這是一致性與安全的刻意設計。
- **關聯**：etcd 的「強一致 + 分散式」直通 [[distributed-systems-advisor]] 的 consensus / Raft、狀態機複製主題；它是整個宣告式系統的「single source of truth」。

### 9. kube-scheduler：決定 Pod 落在哪個 node [0:11:46–0:12:38]
**本段回答的問題**：一個新 Pod 該放到哪台 node 上？誰決定？

- **職責**：scheduler 是 controller node 的元件，負責「Pod 放到哪個 node」的**決策**。講者以 **Tetris**（俄羅斯方塊）比喻——把 Pod 一塊塊擺到 node 上。
- **決策目標**：
  - 盡量讓 Pod 在各 node 間**平均分布（equal distribution）**。
  - 同時**遵守規則（rules）**——無論是你設的（如 node 親和性、資源需求）或系統本身設的。
- **可自主 vs 自動**：你當然可以自己決定落點（在 manifest 明確指定），但通常希望交給 Kubernetes（scheduler）自動決定。
- **限制/誤區**：scheduler 只「決定落點」並回報，不親自把 Pod 建起來——真正動手的是目標 node 上的 kubelet（見第 11、13 段）。
- **關聯**：scheduling 規則是後續 node selector、affinity、taint/toleration、resource request/limit 的基礎；平均分布對應第 3 段「host 資源耗盡」痛點的解法。

### 10. controller-manager：叢集的執法官 [0:12:38–0:13:24]
**本段回答的問題**：誰在確保「該有幾個 Pod 就有幾個」「權限規則被遵守」？

- **比喻**：把 controller-manager 想成 **sheriff（警長/執法官）**——「我在這確保所有 Pod 都守規矩」。
- **職責**：它實際上管理**一堆不同的 daemon（守護程序）**，這些 daemon 控制叢集運行的各種行為。對新手而言下列名詞可能還陌生，但先建立印象：
  - **namespace**：Kubernetes 物件透過 namespace 來追蹤與分組。
  - **RBAC（role based access control）+ ServiceAccount**：透過角色控制物件可被如何操作，並連接到服務帳號。
  - **replica**：你會建立 Pod 的複製份數（replicas），這也需要被追蹤與維持。
- **工程鏡頭（控制迴圈）**：這些 daemon 本質是一組 **controller**，各自不斷比對「期望狀態（desired state）vs 當前狀態（current state）」並收斂差異——這就是 Kubernetes 宣告式模型的執行引擎（雖然本講未展開此術語，但這是其本質）。
- **關聯**：replica 的維持直接對應第 3 段「容器死掉沒人重啟」的痛點（self-healing）；namespace/RBAC 是後續多租戶與安全章節的基礎。

### 11. kubelet：每個 node 的眼睛、耳朵與手腳 [0:13:24–0:14:16]
**本段回答的問題**：controller node 的決策，怎麼真正落到 worker node 上執行？

- **分布位置**：kubelet 存在於**每一個 node**（包括 controller node，不論架構圖是否畫出來）。
- **角色**：kubelet 是每個 node 的「**eyes and ears（眼睛與耳朵）**」，職責繁多：
  - 確保容器在該 node 上被**適當地啟動、停止、重啟**。
  - **接收來自 controller node 的任何指令**。
  - （下一段補充）回報狀態。
- **關鍵風險**：kubelet 是該 node 對叢集其餘部分的**唯一連線（sole connection）**。若某 node 上的 kubelet 出問題，該 node 就等於陷入麻煩、與叢集失聯。
- **限制/誤區**：kubelet 本身不建容器，它是「發指令的手」，實際建容器的是 container runtime（下一段）。
- **關聯**：kubelet 失聯是 node NotReady、Pod 卡住的常見排錯起點；它是控制平面與資料平面之間的橋樑。

### 12. container runtime、image 與 registry：真正建容器的地方 [0:14:16–0:16:03]
**本段回答的問題**：到底是 Kubernetes 還是 Docker 在建容器？兩者是取代關係嗎？

- **常見迷思澄清**：「該用 Docker 還是 Kubernetes？」——這**不是二選一（not either/or）**。用 Kubernetes 時，你仍在用 Docker / containerd 之類的東西。
- **原因**：叢集裡各 node 上的 Pod 內部就是**一如既往的 container**；而建這些容器的**不是 Kubernetes**——每個 node 上都裝有某個 **container runtime engine**（Docker、containerd 等）。
- **誰下指令**：像 `docker run`、`podman run` 這類建容器的指令**在 Kubernetes 裡仍在跑**，但**寫指令的不是你，是 kubelet**——kubelet 負責這些 start/stop/restart/收集資訊的 runtime 指令，實際執行者則是 runtime engine。
- **容器生命週期照舊**：
  - **image（映像檔）**：容器的「picture / template（模板/樣板）」，描述容器該怎麼建、內部應用怎麼設定。
  - **registry（映像倉庫）**：image 必須來自某個儲存處，稱為 registry，可設定成各種不同來源。
- **工程鏡頭（元件分層）**：kubelet（決策執行）↔ CRI（Container Runtime Interface，本講未點名）↔ runtime engine（實作），是「介面與實作分離」的典型設計，讓 Kubernetes 能替換底層 runtime（Docker → containerd）而不影響上層。
- **關聯**：image/registry 是後續 `image:` 欄位、ImagePullBackOff 排錯、私有 registry 認證的基礎；runtime 觀念連到容器與 Linux 基礎。

### 13. 端到端：`kubectl create pod` 的完整控制流 [0:16:03–0:19:52]
**本段回答的問題**：把所有元件串起來——下一個建 Pod 指令後，內部到底發生了什麼？

- **前提**：你會寫一份 **manifest**（宣告式文件，含「Kubernetes 該做什麼、怎麼建」的所有指示），透過 kubectl 送出。
- **完整流程（東西向來回）**：
  1. **kubectl create**：用 kubectl 指令建立 Pod，資訊送到 controller node，由 **API server** 接收（API server 流量極大、非常忙）。
  2. **API server → etcd（寫期望）**：若沒被直接拒絕（可能因 typo 或無授權而 reject），API server 告訴 etcd「這是我們要建的 Pod」。etcd 回 **HTTP 200（thumbs up，OK）**。
  3. **API server → 使用者**：API server 回覆你的命令列「looks good boss，要來建這個 Pod 了」。**但 Pod 此時還沒真的建好（not by a long shot）**。
  4. **API server → scheduler（問落點）**：API server 需知道 Pod 要放哪，於是問 scheduler。若 manifest 沒明確指定，scheduler 決定——例如選 **worker node 2**。
  5. **回寫 etcd**：決定回傳 API server；API server 通知 etcd「Pod 放 node 2」，etcd 回 OK；API server 也回 scheduler「good pick，就 node 2」。——大量 back and forth，用來確定資源實際落在叢集何處。
  6. **API server → 目標 node 的 kubelet**：API server（在 controller node 內）reach out 到選定的 worker node 2，把任務交給該 node 上的 **kubelet**。
  7. **kubelet → runtime（真正動手）**：kubelet「got it boss」，轉身執行必要指令（`docker run` / `containerd start` 等）。**此刻容器才真正被建立**；也是 kubelet 負責建立**裝容器的那個 Pod**。
  8. **順序定論**：**先建 Pod、後建 container**（不是雞生蛋問題）。
  9. **kubelet → API server → etcd（持續回報）**：kubelet 持續 feed 狀態更新（容器建立中／完成／進入 error 或 stop 狀態），API server 收到後確保這些資訊被記錄回 etcd。
- **工程鏡頭（宣告式 + 非同步 reconcile）**：使用者收到「OK」時只代表「期望狀態已被記錄」，實際建立是**非同步**發生的收斂過程；狀態的唯一真相寫在 etcd，各元件透過 API server 讀寫並回報，形成閉環。
- **關聯**：這條流程是排錯的地圖——Pod Pending 多半卡在 scheduler；容器起不來多半在 kubelet/runtime；狀態不一致看 etcd/API server。

### 14. 為何理解架構等於 troubleshooting 能力 [0:19:52–0:20:11]
**本段回答的問題**：學這些元件圖有什麼實際用處？

- **核心價值**：理解「這些元件是什麼、如何協同運作」是一個「nifty little ecosystem」，能實際幫助你 **troubleshoot（排錯）**，也更懂得如何建立資源、並確認它們運行且健康（working and healthy）。
- **工程鏡頭**：架構知識把「Pod 起不來」這種模糊症狀，轉譯成「是哪一環（kubectl 認證？API server 授權？scheduler 排不進？kubelet 失聯？runtime 拉不到 image？etcd 狀態異常？）」的可定位問題。
- **關聯**：本段收束整講，為後續實作與排錯章節（Pending / CrashLoopBackOff / ImagePullBackOff / OOMKilled）鋪路。

## 🧪 例子、案例與應用

- **「it worked on my computer → then we'll ship your computer」**：說明容器**可攜性**的經典笑話——容器把環境一起打包，消弭「開發機能跑、上線機不能跑」的落差。
- **三大災難場景**：具體演示「沒有 Kubernetes 時」單 VM 跑容器的三種失敗，是理解 Kubernetes 每個自動化功能「解決什麼」的錨點。
- **Tetris 比喻（scheduler）**：把 Pod 當方塊、node 當棋盤，直覺化「平均分布 + 遵守規則」的排程目標。
- **Sheriff 比喻（controller-manager）**：把「維持期望狀態、執行規則」的控制迴圈擬人化為執法官。
- **建 Pod 的端到端流程**：把六大元件（kubectl、API server、etcd、scheduler、kubelet、runtime）用一條真實動作串起，是本講最重要的整合案例。
- **實務延伸（GKE）**：在雲端，控制平面（API server、etcd、scheduler、controller-manager）多由平台託管，使用者主要操作 worker node 與 workload——見 [[gke-deploy]] skill。

## ⚠️ 常見誤解與反例

- **誤解：Kubernetes 取代 Docker。**
  - **釐清**：不是二選一。Kubernetes 是編排層，底層仍靠 container runtime（Docker/containerd）建容器；`docker run` 這類指令仍在跑，只是改由 kubelet 下達。
- **誤解：Kubernetes 直接管理容器。**
  - **釐清**：Kubernetes 管的是 **Pod**（容器的 wrapper），不直接管 container。
- **誤解：`kubectl create` 回傳 OK 就代表 Pod 已經跑起來。**
  - **釐清**：回 OK 只代表「期望狀態已寫入 etcd」；實際建立是非同步的，還要經 scheduler 決定落點、kubelet 呼叫 runtime 才真正生出容器。
- **誤解：先有 container 才有 Pod。**
  - **釐清**：順序相反——kubelet 先建 Pod（wrapper），再在其中建 container。
- **誤解：可以把應用 Pod 隨意排到 controller node 上。**
  - **釐清**：controller node 資源要留給控制平面；預設不鼓勵（生產環境常以 taint 阻擋）。
- **誤解：etcd 只是個普通資料庫、掛了再重啟就好。**
  - **釐清**：etcd 存的是**整個叢集的唯一狀態真相**，遺失等於叢集失憶（lobotomy），必須備份與高可用保護。
- **誤解：任何人裝了 kubectl 就能連任何叢集。**
  - **釐清**：必須有正確的 kubeconfig（cluster 位址 + certificate/key）認證通過才行。

## 🧠 深層理解

1. **核心直覺是什麼？** Kubernetes 是一台「宣告式的分散式控制機器」：你描述**想要的最終狀態**（幾個 Pod、用哪個 image），系統透過「API server 收斂到 etcd + 各 controller 不斷比對並修正」把現況拉向期望——你管「what」，它管「how」。
2. **它解決了什麼問題？** 容器化解決了打包與可攜，但留下擴展、自癒、跨機協調、資源調度等維運難題（第 3 段三大災難）。Kubernetes 把這些自動化，讓大規模容器化應用可維運。
3. **它犧牲或忽略了什麼？** 犧牲了簡單性——引入六大元件、etcd 一致性、網路與儲存抽象，學習曲線陡、運維複雜；對小型單機應用是過度設計（over-engineering，見 [[distributed-systems-advisor]] 的「不要過度分散」紀律）。
4. **它和哪些概念容易混淆？** Pod vs container、node vs cluster、controller node vs worker node、kubelet vs container runtime、scheduler（決策）vs kubelet（執行）、declarative vs imperative。
5. **教給初學者的比喻是什麼？** 把叢集想成一間餐廳：kubectl 是點餐的你，API server 是唯一收單的櫃檯，etcd 是記錄所有訂單狀態的帳本，scheduler 是決定哪個廚房做這道菜的領班，controller-manager 是巡場確保出餐規矩的經理，kubelet 是各廚房的主廚（接單並指揮），container runtime 是實際掌廚的爐火。
6. **現實使用的最大限制是什麼？** 控制平面（尤其 etcd）的可用性與正確性是單點命脈；運維複雜度高，通常需要託管服務（GKE/EKS/AKS）或專職 SRE 才能穩定運行。

## 🕒 時間軸索引（Timeline Index）

- 0:00:00–0:01:42：課程定位、講者背景（CKA/CKAD、20 年教學）、學習路徑建議
- 0:01:42–0:03:20：why Kubernetes——microservices、容器四大優勢（易建/易換/可攜/可擴展）
- 0:03:20–0:04:50：容器的宿命 + 傳統單 VM 的三大災難場景
- 0:04:50–0:05:24：Pod 是 Kubernetes 管理的最小單位（wrapper around containers）
- 0:05:24–0:07:22：Node 與 Cluster；worker node vs controller node 分工
- 0:07:22–0:09:35：kubectl CLI 與 kubeconfig（cluster 位址 + certificate/key）
- 0:09:35–0:10:29：kube-apiserver——唯一大門、唯一與 etcd 對話者
- 0:10:29–0:11:46：etcd——強一致分散式 key-value store，存叢集狀態，遺失=lobotomy
- 0:11:46–0:12:38：scheduler——Tetris 式決定 Pod 落點、平均分布 + 遵守規則
- 0:12:38–0:13:24：controller-manager——sheriff，管 namespace/RBAC/replica 等 daemon
- 0:13:24–0:14:16：kubelet——每個 node 的眼耳手腳，node 對叢集的唯一連線
- 0:14:16–0:16:03：container runtime / image / registry；Docker 與 Kubernetes 非二選一
- 0:16:03–0:19:52：端到端 `kubectl create pod` 完整控制流（八步來回）
- 0:19:52–0:20:11：理解架構 = troubleshooting 能力，收束全講

## 💡 重點問答 / 自我測驗

- **Q：Kubernetes 管理的最小單位是什麼？為什麼不是 container？**
  A：是 **Pod**。Pod 是容器的 wrapper，把容器綁成一個可控單元；Kubernetes 只認 Pod（manages Pods, not containers），一個 Pod 可含多個容器。
- **Q：worker node 與 controller node 的差別？為何不該把應用 Pod 放到 controller node？**
  A：worker node 跑絕大多數應用 Pod；controller node 是控制平面工具的樞紐。controller node 很忙、資源要留給管理叢集，隨意塞 Pod 會影響叢集穩定。
- **Q：列出 controller node 上的主要控制平面元件與各自職責。**
  A：kube-apiserver（唯一入口/協調/唯一碰 etcd）、etcd（存整個叢集狀態）、scheduler（決定 Pod 落點）、controller-manager（維持期望狀態，管 namespace/RBAC/replica 等 daemon）；kubelet 則存在於每個 node（含 controller node）。
- **Q：為什麼說「失去 etcd 等於對叢集做 lobotomy」？**
  A：etcd 儲存整個叢集的狀態真相（幾個 node/Pod、是否運行/報錯、能否互通）。遺失就失去對所有運行事物的追蹤，等於叢集失憶，故須謹慎備份。
- **Q：只有誰能跟 etcd 對話？這樣設計的好處？**
  A：只有 **API server**。收斂到單一入口讓一致性、認證、授權、稽核有唯一控制點，避免多元件直接讀寫造成狀態競態。
- **Q：`kubectl create pod` 回傳「OK」時，Pod 真的建好了嗎？**
  A：沒有。「OK」只代表期望狀態已寫入 etcd；之後還要 scheduler 決定落點、kubelet 呼叫 runtime 才真正建出容器，是非同步收斂。
- **Q：先建 Pod 還是先建 container？**
  A：**先建 Pod**（wrapper），再在其中建 container，由 kubelet 負責。
- **Q：scheduler 與 kubelet 的分工？**
  A：scheduler 只**決定** Pod 放哪個 node 並回報；kubelet 在該 node 上**實際執行**——呼叫 runtime 建容器並回報狀態。
- **Q：用 Kubernetes 還需要 Docker 嗎？誰在下 `docker run`？**
  A：需要底層 container runtime（Docker/containerd）；不是二選一。實際下 `docker run` 這類指令的是 **kubelet**，不是使用者。
- **Q：kubectl 要連上叢集需要哪份設定？裡面有什麼？**
  A：**kubeconfig**，含 cluster 位址與 certificate/key file 用來認證身分；沒有它 kubectl 無法運作。
- **Q：image 與 registry 各是什麼？**
  A：image 是容器的模板（怎麼建、內部應用怎麼設定）；registry 是儲存並提供 image 拉取的地方，可設定成不同來源。
- **Q：controller-manager 為何被比喻為 sheriff？**
  A：它管理一群 controller daemon，持續確保物件維持期望狀態（如 replica 數、namespace、RBAC 規則），像執法官維持秩序。
- **Q：（反例題）若 Pod 一直卡在 Pending，依本講架構最先懷疑哪個元件？**
  A：多半是 **scheduler** 找不到合適 node（資源不足或規則不符）；若已排定但容器起不來，則往 kubelet / container runtime（如拉不到 image）方向查。
- **Q：（應用題）為什麼 microservices + container 幾乎必然導向需要一個編排系統？**
  A：微服務把應用拆成大量會死、需擴展、需跨機協調的容器，手動維運三大災難場景不可持續，因此需要 Kubernetes 這類自動化編排。

## 🧩 跨領域連結

- **雲原生維運 ↔ 控制理論**：controller-manager 的「desired state vs current state 持續收斂」就是一個負回饋控制迴圈（closed-loop control），與工程控制系統同構。
- **etcd ↔ 分散式系統一致性**：etcd 的「強一致 + 分散式 key-value」直通 consensus/Raft、狀態機複製與 CAP 取捨，見 [[distributed-systems-advisor]]。
- **Pod/container 隔離 ↔ 作業系統**：容器依賴 Linux namespace 與 cgroup 做隔離與資源限制，是 OS 程序與資源管理的應用。
- **宣告式 API ↔ 資料庫交易/冪等性**：宣告期望狀態、由系統收斂，對應「宣告目標 + 冪等 reconcile」的設計哲學。
- **微服務編排 ↔ 經濟學資源配置**：scheduler 在有限 node 資源下追求「平均分布 + 規則」的配置，類比受限最佳化與資源調度。
- **API server single front door ↔ 資安縱深防禦**：單一入口收斂認證/授權/稽核，是安全架構「收窄攻擊面、集中管控」的體現。

## 🔗 延伸學習路徑

- **下一步應學**：
  - [[Lesson_2_Pods_and_kubectl_Basics]]：親手用 kubectl 與 manifest 建立第一個 Pod（本講預告的實作）。
  - Deployment / ReplicaSet：如何維持 replica、滾動更新與回滾（對應「容器死掉自動重啟」）。
  - Service / Ingress：Pod 網路與對外曝露。
  - ConfigMap / Secret、PV / PVC：設定與儲存。
  - namespace / RBAC / ServiceAccount：多租戶與權限。
  - probe（liveness/readiness）與 Pod 故障排查（Pending、CrashLoopBackOff、ImagePullBackOff、OOMKilled）。
- **推薦關鍵字**：Kubernetes control plane、kube-apiserver、etcd Raft、kube-scheduler predicates/priorities、kube-controller-manager、kubelet、CRI（Container Runtime Interface）、containerd、declarative reconciliation、CKA/CKAD。
- **相關人物 / 理論 / 資源**：CNCF（Cloud Native Computing Foundation）、Kubernetes 官方文件 Concepts/Architecture、etcd 官方文件、CKA/CKAD 認證大綱；本 repo 的 [[gke-deploy]] skill（在 GKE 上實際部署與排錯）、[[distributed-systems-advisor]] skill（etcd 一致性與是否過度分散的取捨）。
- **在知識地圖中的位置**：本講是整套課程的「架構總綱」，是所有後續 workload / 網路 / 儲存 / 安全章節掛載的骨架；也是 CKA/CKAD 考試中「Cluster Architecture」領域的入門。

## 📎 附錄：實作範例（教學補充，非逐字稿內容）

> 說明：本講以架構講解為主，講者明言實作「留待後續（we'll be doing this ourselves soon）」。以下 YAML 與 kubectl 範例為對應本講概念的**最小教學示例**，用來把抽象元件落到可操作指令，非取自逐字稿。

**最小 Pod manifest（對應第 4、13 段：Pod 是最小單位、由 manifest 宣告期望狀態）**

```yaml
# pod.yaml — 一個包住單一 nginx container 的 Pod
apiVersion: v1
kind: Pod
metadata:
  name: my-first-pod
  labels:
    app: demo            # label：供 Service/selector 匹配（後續章節）
spec:
  containers:
    - name: web
      image: nginx:1.27  # image 來自 registry（第 12 段）
      ports:
        - containerPort: 80
```

**對應第 13 段控制流的 kubectl 指令**

```bash
# 1) 送出期望狀態 → API server 驗證 → 寫入 etcd（宣告式）
kubectl apply -f pod.yaml

# 2) 觀察狀態收斂：Pending（scheduler 尚未排定）→ ContainerCreating（kubelet 呼叫 runtime）→ Running
kubectl get pod my-first-pod -w

# 3) 看 scheduler 把 Pod 排到哪個 node、以及事件（排錯起點）
kubectl get pod my-first-pod -o wide
kubectl describe pod my-first-pod        # Events 區塊常揭露 Pending / ImagePullBackOff 原因

# 4) 檢視 controller node 元件狀態（在自管叢集上）
kubectl get componentstatuses            # apiserver/etcd/scheduler/controller-manager
kubectl get nodes                        # 各 node 是否 Ready（反映 kubelet 是否健康）

# 5) 用完刪除（容器不設計來永生，第 3 段）
kubectl delete -f pod.yaml
```

**排錯對照表（把第 14 段的「架構即排錯」落地）**

| 症狀 | 最可能的元件環節 | 首查指令 |
|---|---|---|
| Pod 卡在 `Pending` | scheduler 找不到合適 node（資源/規則） | `kubectl describe pod`（看 Events）、`kubectl get nodes` |
| `ImagePullBackOff` | container runtime 從 registry 拉不到 image | `kubectl describe pod`、檢查 image 名稱與 registry 認證 |
| `CrashLoopBackOff` | 容器起得來但應用反覆崩潰 | `kubectl logs <pod> --previous` |
| node `NotReady` | 該 node 的 kubelet 失聯 | `kubectl describe node`、檢查 kubelet 服務 |
| 操作全部逾時/拒絕 | API server 或 kubeconfig 認證問題 | 檢查 kubeconfig、API server 可達性 |

> 校正說明（ASR 修正）：逐字稿為 YouTube 自動轉錄，語言雖被誤標為 Chinese，實際內容為正確英文口語。本筆記已將明顯的同音／口語轉寫校正為標準 Kubernetes 術語：`cube control` → **kubectl**、`cube config` → **kubeconfig**、`cubelet` → **kubelet**、`container d` / `container destart` → **containerd** / containerd 啟動容器、`triple-w`/口語省略處補為標準寫法。元件官方名稱以 **kube-apiserver / etcd / kube-scheduler / kube-controller-manager / kubelet** 標準化呈現。無法可靠還原的口語填充語（如 "yada yada"、"batter up cause here's the pitch" 等行銷/俚語）未逐字保留，僅取其知識內容；不確定處未杜撰。
