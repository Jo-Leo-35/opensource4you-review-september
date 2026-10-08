# Kubernetes FULL COURSE：Lesson 6 — Kubernetes Secrets（安全地存放敏感資料）

> 來源：YouTube 逐字稿 + SRT｜https://www.youtube.com/watch?v=_zoIC7ZmWNE
> transcript_source: [[2025-08-08__zoIC7ZmWNE_Kubernetes-FULL-COURSE-Part-6-Kubernetes-Secrets-–-Secure-Sensitive-Data.txt]]
> 講者：Chad（CKA/CKAD 認證講師，逐字稿標示自述 20 年教學經驗；本段影片未口播全名）
> 時長：約 7:05（00:00:00–00:07:04，單段影片）
> 領域：資訊科學／雲原生（Cloud Native）／DevOps／軟體工程；Kubernetes 組態與機密管理
> 難度：入門到中階（CKA/CKAD 基礎；需先具備 Pod、container、YAML、kubectl、namespace 概念）
> 學習目標：理解 Secret 是什麼、與 [[Lesson_5_Kubernetes_ConfigMaps|ConfigMap]] 的異同；掌握 Secret 的 type（Opaque / basic-auth / ssh-auth）；用宣告式（manifest）與命令式（`kubectl create secret --from-literal`）兩種方式建立 Secret；把 Secret 透過 `env` + `secretKeyRef` 注入容器環境變數；用 `kubectl get / describe / exec` 檢視與驗證；並徹底理解「**Secret 預設不加密、只是 base64 編碼**」這個安全陷阱，以及生產環境該補上的 encryption at rest / RBAC。

## 📌 一句話總覽

本單元處理一個所有真實應用都會遇到的工程問題：**應用需要密碼、token、金鑰等敏感組態，但我們不希望把它們硬寫（hard-code）在容器映像檔或 manifest 裡**。Kubernetes 的答案是 `Secret` 物件——它與上一講的 [[Lesson_5_Kubernetes_ConfigMaps|ConfigMap]] 幾乎是雙胞胎（把資料存在物件自身、而非烤進 container），建立流程也幾乎一模一樣，差別只在 Secret 專門承載敏感資訊、且有專屬的 `type`（如 `Opaque`、`kubernetes.io/basic-auth`、`kubernetes.io/ssh-auth`）。但本講最重要的一句話是講者反覆強調的警告：**Secret 本身「不加密」，它只是 base64 編碼並明文存放在 API server 背後的 etcd 裡**；任何拿得到 API 存取權（透過 kubectl）的人都能讀出、甚至修改它。真正的機密保護要靠你自己另外啟用 encryption at rest 或外部 KMS，並用 RBAC 限制存取——這些「out of the box 不會幫你做」。講者用一個 MySQL 容器示範完整資料流：建立一個 `basic-auth` 型別、key 為 `password` 的 Secret → 用 `env` + `secretKeyRef` 把它注入容器的 `MYSQL_ROOT_PASSWORD` 環境變數 → 建立 Pod → 用 `kubectl exec` + `echo` 印出環境變數，當場「揭穿」密碼明文可見，證明 Secret 未加密。它在整個課程知識體系中，緊接在 ConfigMap 之後、屬於「組態與資料注入」這一組主題，是後續 [[Lesson_7_Kubernetes_Persistent_Volumes|儲存]]、部署與 [[gke-deploy]] 實務的基礎能力。

## 🧭 知識地圖（Knowledge Map）

- **前置知識**：Pod 與 container 概念、YAML manifest 語法、`kubectl` 基本操作、[[Lesson_5_Kubernetes_ConfigMaps|ConfigMap]]（Secret 幾乎是它的孿生兄弟）、namespace（Secret 是 namespaced 資源）、環境變數（environment variable）與 base64 編碼。
- **本集核心**：Secret 的用途與 type、宣告式 vs 命令式建立、`data` vs `stringData`、`env` + `secretKeyRef` 注入資料流、`kubectl get/describe/exec` 檢視、**「Secret ≠ 加密，只是 base64」的核心安全命題**、namespace 對齊、與 ConfigMap 的可互換性、考試（CKA/CKAD）對 Secret 的期待。
- **後續會連到**：encryption at rest（`EncryptionConfiguration`）、外部 KMS（AWS KMS、GCP Cloud KMS、Vault）、RBAC 對 Secret 的存取控制、Secret 以 volume mount 方式注入檔案、`imagePullSecrets`、TLS 型別 Secret；[[Lesson_7_Kubernetes_Persistent_Volumes|PV/PVC 持久化儲存]]、Deployment 與 [[gke-deploy]] 部署實務。
- **可跨領域連結**：資訊安全的「機密管理（secrets management）」與最小權限原則、密碼學的編碼 vs 加密之別、作業系統的環境變數與 process 記憶體、合規稽核（audit）與 12-Factor App 的「config 與 code 分離」原則。

## 🎯 核心重點（Core Takeaways）

- **Secret 與 ConfigMap 是同一套機制的兩種用途**：兩者都把資料存在「物件自身」而非烤進 container 映像檔，讓組態與程式碼解耦；差別只在 Secret 專門承載敏感資料（密碼、token、key），且擁有專屬 type 與稍微不同的呈現方式。
- **Secret 預設「不加密」，只是 base64 編碼**：這是本講最重要、講者反覆強調的一點。Secret 明文（base64）存在 API server 背後的 **etcd**，`base64` 只是可逆編碼、不是加密，任何能存取 API 的人都能還原。
- **誰能看到 Secret**：任何有 API 存取權、能用 kubectl 的人，都能 **看到、修改** 該 Secret；因此 Secret 的真正防線是 RBAC（誰能存取 API）而非 Secret 物件本身。
- **加密要自己補**：Kubernetes 要求你「自帶」加密方案（encryption at rest / 外部 KMS）；out of the box 不會替你加密——這是設計上的空缺，不是 bug。
- **Secret 有多種 type**：`Opaque`（generic，最通用、任意鍵值，如憑證檔）、`kubernetes.io/basic-auth`（帳密情境）、`kubernetes.io/ssh-auth`（SSH 認證）等；type 只是語意標籤與欄位驗證約定，不改變「未加密」的事實。
- **Secret 是 namespaced 資源**：Secret 與 Pod、ConfigMap 一樣屬於某個 namespace；要使用 Secret 的 Pod **必須與該 Secret 在同一個 namespace**，否則找不到。
- **兩種建立方式**：宣告式（寫 manifest 用 `kubectl create/apply -f`，可版本控管、可重現）與命令式（`kubectl create secret <type> --from-literal=key=value`，快速、適合臨時）。`--from-literal` 對 ConfigMap 也適用。
- **`data` 需 base64、`stringData` 收明文**：manifest 中 `data:` 欄位的值必須是 base64 字串，`stringData:` 則接受明文（Kubernetes 幫你編碼），後者對人類更友善。
- **注入容器的資料流**：在容器 spec 的 `env` 底下，用 `valueFrom.secretKeyRef`（指定 Secret 的 `name` + 要取的 `key`）把 Secret 的某個值綁到某個環境變數，避免把密碼明文寫進 Pod manifest。
- **反例（絕不要做）**：直接在 manifest 裡 `env` 給 `value: <明文密碼>`——講者以「所有資安人員都中風了」誇張地強調這是錯誤示範。
- **`kubectl describe secret` 不顯示值**：describe 只告訴你有哪些 key（例如 `password`）以及其位元組長度，不印出 value；但這只是 UI 上的遮蔽，**不代表安全**，仍可用其他指令把值挖出來。
- **`kubectl exec` + `echo` 可驗證/揭穿**：進到容器內 `echo $ENV_VAR` 會直接印出明文密碼，既驗證注入成功，也再次證明 Secret 未加密。
- **容器不保證瞬間啟動**：用 `kubectl get pods -w`（`-w` = watch/wait）持續觀察狀態變化；有些 image（如 MySQL）需要幾秒才進入 Running。
- **Secret 與 ConfigMap 高度可互換**：本講示範的 `env` 注入方式，把 `secretKeyRef` 換成 `configMapKeyRef` 即可對 ConfigMap 做同樣的事；差別只在資料是否敏感。
- **考試視角**：對 CKA/CKAD 而言，重點是「會建立、會注入、會檢視」Secret；**設定加密（encryption at rest）不會考**，講者明說考試不必擔心這塊。

## 🔑 關鍵字與術語表（Keywords & Glossary）

| 術語 | 原文 / 符號 | 說明 |
|---|---|---|
| 機密 | Secret | Kubernetes 內建物件，用來存放密碼、token、key 等敏感資料；預設僅 base64 編碼，非加密 |
| 組態對照表 | ConfigMap | 與 Secret 孿生的物件，存放非敏感組態；建立與注入流程幾乎相同 |
| 容器 | container | 執行應用的隔離單元；Secret/ConfigMap 讓組態不必烤進容器映像檔 |
| 群集資料庫 | etcd | Kubernetes 的鍵值儲存後端；所有物件（含 Secret）明文（base64）存於此 |
| API 伺服器 | API server | 叢集的統一入口；讀寫 Secret 都經過它，存取權即決定誰能看 Secret |
| 命令列工具 | kubectl | 操作叢集的 CLI（逐字稿 ASR 誤作 "kube control"/"cube control"） |
| 命名空間 | namespace | 資源的邏輯隔離單位；Secret 與使用它的 Pod 必須同 namespace |
| 不透明型別 | Opaque | 最通用的 generic Secret type，任意鍵值（如憑證檔） |
| 基本認證型別 | kubernetes.io/basic-auth | 用於帳號密碼情境的 Secret type（本講示範用它） |
| SSH 認證型別 | kubernetes.io/ssh-auth | 用於 SSH 私鑰認證的 Secret type |
| 靜態加密 | encryption at rest | 在 etcd 落盤前對 Secret 加密的機制；需自行以 `EncryptionConfiguration` 或外部 KMS 啟用 |
| 金鑰管理服務 | KMS | 外部金鑰管理（AWS/GCP KMS、HashiCorp Vault）；提供真正的加密與輪替 |
| 編碼 | base64 | 可逆的編碼（非加密）；Secret 的值以此形式存放，可被任何人解回明文 |
| 資料欄位 | data | manifest 中放 base64 編碼值的欄位 |
| 明文資料欄位 | stringData | manifest 中放明文值的欄位，Kubernetes 會自動編碼成 base64 存入 |
| 由字面值建立 | --from-literal | 命令式建立時直接指定 `key=value`；對 ConfigMap 亦適用 |
| 環境變數 | env / environment variable | 容器 spec 的欄位；應用透過環境變數讀組態 |
| 機密鍵參照 | secretKeyRef | `valueFrom` 下的參照，指定 Secret 的 `name` 與 `key` 把值綁到環境變數 |
| 組態鍵參照 | configMapKeyRef | 與 secretKeyRef 對應的 ConfigMap 版本 |
| 宣告式 | declarative | 寫 manifest 描述期望狀態，`kubectl apply/create -f`；可版本控管 |
| 命令式 | imperative | 直接下指令改變狀態（如 `kubectl create secret ...`）；快速但難重現 |
| 監看旗標 | -w / --watch | `kubectl get pods -w`：持續輸出資源狀態變化 |
| 進入容器執行 | kubectl exec | 在執行中的容器內執行指令（如 `echo $VAR`），用來驗證/除錯 |
| 存取控制 | RBAC | Role-Based Access Control；限制誰能對 Secret 做何種操作，是 Secret 真正的防線 |

## 📖 詳細筆記（Detailed Notes）

### 1. 從 ConfigMap 到 Secret：為何需要一個新物件 [00:00:00–00:00:41]

**本段問題**：學過 ConfigMap 之後，為什麼還要 Secret？兩者關係為何？

- **系統模型**：Secret 與 [[Lesson_5_Kubernetes_ConfigMaps|ConfigMap]] 非常相似——兩者都把資料「存在物件自身」，而不是把資料烤進 container 映像檔。這樣做的核心價值是**組態與程式碼解耦**（config 與 code 分離），同一個 image 可在不同環境注入不同組態。
- **差別（唯一關鍵）**：Secret 顧名思義是「機密」——它承載的是 **密碼（passwords）、token、key** 這類敏感資訊；ConfigMap 則承載一般（非敏感）組態。
- **學習成本低**：講者強調 Secret 的建立流程與 ConfigMap「幾乎一模一樣」，所以新概念不多；真正要學的是幾個關於「使用 Secret 的警告」。
- **關聯**：本講的注入示範（第 7 段）刻意做到「把 secretKeyRef 換成 configMapKeyRef 就變成 ConfigMap 版本」，凸顯兩者的可互換性（第 11 段）。

### 2. Secret 的核心警告：預設不加密，只有 base64 [00:00:41–00:01:17]

**本段問題**：Secret 到底安不安全？它把資料放在哪、誰能看到？

- **核心命題**：**Secret 本身並不加密（"Secrets on their own are not encrypted"）**。這是整講最重要的一句話。
- **存放位置**：Secret 明文存在 **API server 背後的 etcd**（Kubernetes 的鍵值資料庫）裡。它只是被 base64 編碼——而 **base64 是編碼、不是加密**，可被任何人輕易解回明文。
- **威脅模型**：任何擁有 **API 存取權、能使用 kubectl** 的人，都能 **看到（see）、修改（change）** 叢集裡的 Secret。換言之，Secret 的機密性完全取決於「誰能存取 API」，而不是 Secret 物件自帶任何保護。
- **加密要自己補**：Kubernetes **要求你自帶加密方案（"require you to use your own encryption solution"）**；達成方式很多（本講不深入），但務必知道「out of the box 不會加密」。
- **工程 trade-off**：把「加密」外包給使用者，換來的是 Secret 機制本身簡單、通用、與 ConfigMap 一致；代價是預設狀態並不安全，容易讓初學者誤以為「叫 Secret 就安全」。
- **關聯**：這個缺口在第 12 段（encryption at rest / KMS）與第 13 段（RBAC）補齊；也是第 6、10 段「describe 看不到、但 exec/echo 能挖出來」的根因。

### 3. Secret 的種類（type）：Opaque / basic-auth / ssh-auth [00:01:17–00:01:53]

**本段問題**：Secret 有哪些型別？該怎麼選？

- **有多種 type**：畫面上的表格列出多種 Secret 型別，各對應特定情境：
  - `kubernetes.io/ssh-auth`：**SSH 認證**（存 SSH 私鑰）。
  - `kubernetes.io/basic-auth`：**帳號密碼（basic auth）** 情境；本講的示範就用它。
  - **`Opaque`（generic）**：最通用的型別，語意是「這只是一些任意資料（例如一個 cert 憑證檔），我們不希望別人看到裡面的內容」。未指定 type 時的預設即 `Opaque`。
- **type 的意義**：type 是**語意標籤 + 欄位驗證約定**（例如某些內建 type 期待特定 key）。它幫助工具與人理解 Secret 的用途，但**不改變「未加密」的事實**——任何 type 都只是 base64。
- **工程視角**：選 type 主要是為了與生態工具（如某些 controller、`imagePullSecrets`、TLS）對齊；純粹存任意鍵值就用 `Opaque`。
- **關聯**：第 4 段的 manifest 即以 `basic-auth` 建立一個含 `password` key 的 Secret。

### 4. 宣告式建立 Secret：manifest 與 namespace 邊界 [00:01:53–00:02:27]

**本段問題**：如何用 YAML manifest 建立一個 Secret？要注意什麼邊界？

- **namespace 對齊（關鍵）**：Secret 與 ConfigMap、Pod 一樣是 **namespaced 資源**。**要使用某 Secret 的 Pod，必須和該 Secret 在同一個 namespace**，否則參照不到。ConfigMap 亦然。
- **本講的 Secret 內容**：type 為 `basic-auth`；key 為 `password`；value 為講者口播的「alta3 / all-to-three」（ASR 不確定，見文末校正說明）。
- **manifest 範例**（見「實作範例」章節的完整版）：核心是 `kind: Secret`、`type:`、以及承載鍵值的 `data`（需 base64）或 `stringData`（收明文）。
- **易錯點**：講者提醒「**記得存檔（save）**，否則 `kubectl create -f` 讀到的是舊內容、建立不會如你所願」。這是宣告式流程常見的低級錯誤。
- **關聯**：命令式的等價做法見第 5 段；建立後如何檢視見第 6 段。

### 5. 命令式建立 Secret：kubectl create 與 --from-literal [00:02:27–00:03:11]

**本段問題**：不寫 manifest，能不能用一行指令建立 Secret？

- **命令式（imperative）**：如同建立 ConfigMap，也可用 `kubectl create secret ...` 指令建立。你必須**明確指定 Secret 的 type**，再把鍵值以 `--from-literal=key=value` 帶入。
- **`--from-literal` 的通用性**：這個旗標建立 ConfigMap 時同樣可用，能很方便地把 key/value 對塞進物件。
- **兩種風格的取捨（trade-off）**：
  - **命令式**：快、適合臨時或一次性；缺點是難以版本控管、難重現、不利 GitOps。
  - **宣告式（manifest）**：可進 Git、可重現、可 code review；本講後續選擇用 manifest。
- **關聯**：本講主線走 manifest（第 4 段），命令式僅作為對照提及。

### 6. 檢視 Secret：get 與 describe 的行為 [00:03:11–00:03:53]

**本段問題**：建立完怎麼確認？describe 會不會把密碼印出來？

- **列出**：`kubectl get secrets` 可像其他資源一樣列出所有 Secret。
- **描述**：`kubectl describe secret mysql-secret` 會告訴你「有一個 key 叫 `password`」，但**不顯示它的 value**（通常只顯示 bytes 長度）。
- **關鍵警語**：這種「看不到值」只是 **CLI 層的遮蔽（redaction），不等於安全**。講者強調：他絕對能「爬進這個物件（crawl inside this object）」把 `password` 的實際值挖出來。
- **工程含義**：`describe` 的遮蔽是防止「肩窺（shoulder surfing）」等意外洩漏的貼心設計，但對有 API 權限的人毫無阻擋作用——再次呼應第 2 段。
- **關聯**：第 10 段用 `exec` + `echo` 真的把明文挖出來，坐實此段的警告。

### 7. 把 Secret 餵進容器：env + secretKeyRef 的資料流 [00:03:53–00:05:16]

**本段問題**：建好的 Secret 怎麼被容器（這裡是 MySQL）實際使用？

- **場景**：把 Secret 的內容「讀進」一個正在組裝的 **MySQL 資料庫容器**。講者強調這一切也完全適用於 ConfigMap（兩者可互換，第 11 段）。
- **切入點**：容器 spec 有一個關鍵欄位 `env`（環境變數）。MySQL 官方 image 已內建一個名為 **`MYSQL_ROOT_PASSWORD`** 的環境變數約定，只要設好它，MySQL 啟動時就會用該值當 root 密碼。
- **控制流（正確做法）**：不要把值直接寫死，而是宣告「這個環境變數的 value **來自一個 Secret 的某個 key**」：
  - 用 `valueFrom.secretKeyRef`；
  - `name`：指向 Secret 名稱（本講為 `mysql-secret`，可先用 `kubectl get secrets` 確認名稱）；
  - `key`：指向 Secret 裡的鍵（本講字面就叫 `password`）。
- **資料流總結**：`Secret(mysql-secret).password` → `secretKeyRef` → 容器環境變數 `MYSQL_ROOT_PASSWORD` → MySQL 程式讀取。密碼從頭到尾**不出現在 Pod manifest** 裡。
- **關聯**：反例（把密碼寫死）見第 8 段；完整 YAML 見「實作範例」。

### 8. 反例：把密碼寫死在 manifest（plaintext 的罪） [00:04:40–00:05:04]

**本段問題**：如果偷懶，直接把密碼寫進 Pod manifest 會怎樣？

- **反例做法**：在 `env` 下直接寫 `value: alta3`（明文密碼）。技術上「能動」，但這等於把密碼硬寫進 manifest。
- **講者的誇張強調**：「Yeah that'd be dumb... 把密碼明文放進 manifest，沒人這樣幹啦」「所有資安人員都中風了（all the security people just had a stroke）」——用幽默凸顯這是**明確的反模式**。
- **為何是錯**：manifest 通常會進版本控制（Git）、被多人 review、被 CI 讀取；明文密碼一旦進 repo，形同對所有能讀 repo 的人洩漏，且難以徹底清除歷史。
- **正解**：改用 `secretKeyRef`（第 7 段），讓 manifest 只保留「參照」而非「值」。
- **關聯**：這與第 2 段「Secret 也只是 base64」形成層次——即使用了 Secret 仍需 encryption at rest（第 12 段），但至少不該把密碼直接攤在 Pod manifest。

### 9. 部署與觀察 Pod：kubectl get pods -w [00:05:16–00:06:20]

**本段問題**：建立 Pod 後如何觀察它是否起來？

- **建立**：存檔後 `kubectl create -f pod.yaml` 建立 Pod。
- **觀察**：`kubectl get pods -w`——`-w` 代表 **watch/wait**，會**持續輸出**資源狀態變化，直到你中止；適合等待 Pod 從 `ContainerCreating` 變成 `Running`。
- **實務觀察**：講者示範時 Pod「花了比預期更久」才起來，藉此點出 **容器不保證瞬間啟動（don't always spin up instantaneously）**——像 MySQL 這類 image 較大、初始化較久。
- **故障排查銜接**：若卡在 `Pending`、`ImagePullBackOff`、`CrashLoopBackOff` 等，需進一步 `kubectl describe pod` / `kubectl logs`（本講未展開，見 [[gke-deploy]] 排障流程）。
- **關聯**：Pod 起來後，第 10 段進入容器驗證注入是否成功。

### 10. 驗證與「揭穿」：exec + echo 證明未加密 [00:06:20–00:07:04]

**本段問題**：怎麼確認密碼真的被注入？順便驗證「未加密」的說法？

- **進容器**：`kubectl exec` 進入執行中的容器。
- **印環境變數**：用 `echo $MYSQL_ROOT_PASSWORD`（示範用 echo 印出剛才設定的那個環境變數）——螢幕上**直接出現我們設定的明文密碼**。
- **雙重意義**：
  1. **功能驗證**：注入確實成功，Secret → 環境變數的資料流可用。
  2. **安全揭穿**："Secrets ain't encrypted"——能一行 `echo` 就看到明文，再次坐實 Secret 未加密。
- **收尾叮嚀**：務必「把該做的都做好（get your ducks in a row）」——真正上線前要設定好加密。
- **考試視角**：對考試（CKA/CKAD）而言，**不必擔心 encryption 的設定，那不會考**；考的是會建立、注入、檢視 Secret。
- **關聯**：加密缺口的補法見第 12 段；存取控制見第 13 段；考試範圍見第 14 段。

### 11. Secret vs ConfigMap：職責分工與可互換性（綜合）

**本段問題**：什麼時候用 Secret、什麼時候用 ConfigMap？兩者到底多像？

- **可互換性**：講者反覆強調兩者「非常可互換（very interchangeable）」——本講的注入方式，把 `secretKeyRef` 換成 `configMapKeyRef`（把 Secret 換成 ConfigMap）即成立。
- **職責分工**：
  - **ConfigMap**：非敏感組態（feature flag、URL、port、log level、設定檔）。
  - **Secret**：敏感資料（密碼、API token、TLS 私鑰、SSH key）。
- **實作差異（微小）**：Secret 有 `type` 欄位、值以 base64（`data`）或明文（`stringData`）呈現、`describe` 會遮蔽值；ConfigMap 直接明文、無 type 遮蔽。
- **選型原則**：資料「洩漏會造成損害」→ Secret；否則 → ConfigMap。兩者都應與使用它的 Pod 同 namespace。
- **關聯**：對照 [[Lesson_5_Kubernetes_ConfigMaps|Lesson 5 ConfigMap]] 的注入方式；兩講合起來構成「組態注入」主題。

### 12. 生產環境的加密缺口：encryption at rest 與外部 KMS（工程延伸）

**本段問題**：講者說「自己補加密」，實務上怎麼補？

- **問題根源**：Secret 明文（base64）存在 etcd，若 etcd 磁碟、備份或快照被取得，Secret 等同外洩。
- **補法一：encryption at rest**：在 API server 設定 `EncryptionConfiguration`，指定加密 provider（如 `aescbc`、`aesgcm`），讓 Secret 落盤到 etcd 前先加密。這是「Kubernetes 內建但需自行啟用」的機制。
- **補法二：外部 KMS**：接 AWS KMS、GCP Cloud KMS、Azure Key Vault、或 HashiCorp Vault，把金鑰管理與輪替（rotation）外包給專業服務，安全性與稽核性更佳。
- **補法三：不落地**：用 Vault Agent / CSI Secrets Store driver 在執行期把機密直接掛進 Pod，避免長期存在 etcd。
- **注意**：即使啟用 encryption at rest，**執行中的容器內環境變數仍是明文**（第 10 段已示），因此還需搭配 RBAC 與最小權限（第 13 段）。
- **關聯**：本段對應第 2、10 段點出的缺口；屬課程之外的工程延伸，考試不考（第 14 段）。

### 13. RBAC 與 Secret 存取控制：Secret 真正的防線（工程延伸）

**本段問題**：既然 Secret 不加密，靠什麼防止別人讀？

- **核心認知**：Secret 的機密性 ≈ **「誰能存取 API server / etcd」**。因此真正的防線是 **RBAC（Role-Based Access Control）**——限制哪些使用者/ServiceAccount 能對哪個 namespace 的 Secret 做 `get`/`list`/`watch`/`edit`。
- **最小權限**：不要給所有 ServiceAccount 讀全叢集 Secret 的權限；用 Role/RoleBinding 精準綁定到需要的 namespace 與資源。
- **配套**：關閉不必要的 Secret 自動掛載（Pod 的 `automountServiceAccountToken: false`）、開啟 audit log 追蹤誰讀過 Secret、限制 `kubectl exec`（否則如第 10 段可直接 echo 出明文）。
- **關聯**：與第 2 段的威脅模型（有 API 權限就能看）直接對應；是生產環境的必修配套。

### 14. 考試視角：CKA/CKAD 對 Secret 的期待（後設）

**本段問題**：考試會考 Secret 的哪些部分？

- **會考（動手）**：建立 Secret（宣告式與命令式）、用 `env`/`secretKeyRef`（或 volume mount）把 Secret 注入 Pod、用 `kubectl get/describe` 檢視、確認 Pod 正確取用。
- **不會考**：**設定 encryption at rest 不會考**（講者明說）。加密屬叢集管理員的進階/一次性設定，不在 CKA/CKAD 動手範圍。
- **應試心法**：熟練 `kubectl create secret generic/tls/docker-registry ... --from-literal/--from-file`、`kubectl create secret ... --dry-run=client -o yaml` 產出 manifest 骨架，能在時間壓力下快速完成。
- **關聯**：本講的示範動線（建立→注入→驗證）正好對齊考試常見任務。

## 🧪 例子、案例與應用

- **MySQL root 密碼注入（本講主案例）**：建立 `basic-auth` 型別、key 為 `password` 的 `mysql-secret`，再用 `secretKeyRef` 綁到 MySQL 容器的 `MYSQL_ROOT_PASSWORD`。示範了「敏感值不進 Pod manifest」的標準做法。
- **憑證檔（cert file）當 Opaque Secret**：講者提到 `Opaque` 的典型用途——存一個 cert 之類的任意檔案，不希望被人看到內容。
- **SSH 私鑰（ssh-auth）**：需要用 SSH key 對外認證（如 Git clone 私有 repo、連遠端主機）時，用 `kubernetes.io/ssh-auth` 型別。
- **`imagePullSecrets`（延伸）**：從私有 registry 拉映像檔時，用 `docker-registry` 型別 Secret 存放憑證——本講未展開，屬同族應用。
- **與 ConfigMap 對照**：同樣的 `env` 注入模式套在非敏感組態（如 `LOG_LEVEL`）上就用 ConfigMap + `configMapKeyRef`。

## ⚠️ 常見誤解與反例

- **誤解**：「叫 Secret 就是加密、就安全。」
  - **釐清**：Secret 預設**只做 base64 編碼、不加密**，明文存在 etcd；安全靠 RBAC + encryption at rest 另外補。
- **誤解**：「`kubectl describe` 看不到值，代表值被保護了。」
  - **釐清**：那只是 CLI 遮蔽；有 API 權限者可用 `-o yaml` + `base64 -d` 或進容器 `echo` 取回明文（第 6、10 段）。
- **誤解**：「base64 是一種加密。」
  - **釐清**：base64 是**可逆編碼**，人人可解，毫無保密力。
- **誤解**：「Secret 可以跨 namespace 給任意 Pod 用。」
  - **釐清**：Secret 是 namespaced，Pod 只能引用**同 namespace** 的 Secret。
- **反例（別做）**：把密碼以 `value: <明文>` 直接寫進 Pod manifest（第 8 段）——會隨 Git/CI 洩漏。改用 `secretKeyRef`。
- **誤解**：「用了 Secret，容器裡就看不到明文了。」
  - **釐清**：注入成環境變數後，容器內 `echo $VAR` 仍是明文；這是設計，不是漏洞。需靠 RBAC 限制 `exec` 與存取。

## 🧠 深層理解

1. **核心直覺是什麼？** 把「敏感組態」從程式碼與映像檔中抽離，變成叢集裡可獨立管理、可參照的物件；Secret 是這個抽離動作的「敏感版容器」。
2. **它解決了什麼問題？** 讓同一個 image 在不同環境注入不同機密，且密碼不必硬寫進 code/manifest，達成 12-Factor 的 config 與 code 分離。
3. **它犧牲或忽略了什麼？** 為了與 ConfigMap 保持一致與簡單，Secret **本身不提供加密**，把機密性外包給 etcd 加密與 RBAC；初學者容易誤以為「已受保護」。
4. **它和哪些概念容易混淆？** 與 ConfigMap（差別只在敏感與否 + type）、與 base64「加密」的錯覺、與「describe 遮蔽 = 安全」的錯覺。
5. **教給初學者的比喻是什麼？** Secret 像一個貼了「機密」標籤、但**沒上鎖**的抽屜：標籤提醒大家別亂看、UI 幫你把內容蓋起來，但抽屜本身沒鎖——真正的鎖是房間門禁（RBAC）與保險箱（encryption at rest）。
6. **現實使用的最大限制是什麼？** 預設不加密 + 容器內明文可見 + 有 API 權限即可讀取；生產環境必須額外配置 encryption at rest、外部 KMS、RBAC、audit，才算真正「安全地存放敏感資料」。

## 🕒 時間軸索引（Timeline Index）

- 00:00:00–00:00:41：Secret 與 ConfigMap 的異同、為何需要 Secret（§1）
- 00:00:41–00:01:17：核心警告——Secret 不加密、存在 etcd、需自帶加密（§2）
- 00:01:17–00:01:53：Secret 的多種 type（ssh-auth / basic-auth / Opaque）（§3）
- 00:01:53–00:02:27：宣告式 manifest、namespace 對齊、basic-auth + password（§4）
- 00:02:27–00:03:11：命令式 `kubectl create secret` 與 `--from-literal`，兩種風格取捨（§5）
- 00:03:11–00:03:53：`kubectl get/describe secret`，describe 遮蔽值但不安全（§6）
- 00:03:53–00:05:16：`env` + `secretKeyRef` 把 Secret 注入 MySQL 容器（§7）
- 00:04:40–00:05:04：反例——把密碼明文寫進 manifest（§8）
- 00:05:16–00:06:20：建立 Pod、`kubectl get pods -w`，容器非瞬間啟動（§9）
- 00:06:20–00:07:04：`kubectl exec` + `echo` 驗證並揭穿明文、考試不考加密（§10）

## 💡 重點問答 / 自我測驗

- **Q：Secret 與 ConfigMap 最本質的差別是什麼？**
  A：用途——Secret 存敏感資料（密碼/token/key）且有專屬 type 與值遮蔽，ConfigMap 存非敏感組態；機制與注入方式幾乎相同，可互換。
- **Q：「Secret 是加密的」對嗎？**
  A：不對。Secret 預設只是 base64 **編碼**、明文存在 etcd；base64 可逆、非加密。加密需自行啟用 encryption at rest 或外部 KMS。
- **Q：Secret 存放在叢集何處？誰能讀取？**
  A：存在 API server 背後的 etcd；任何有 API 存取權（能用 kubectl）的人都能讀取甚至修改，因此 RBAC 是真正的防線。
- **Q：`data` 與 `stringData` 有何差異？**
  A：`data` 的值必須是 base64 字串；`stringData` 接受明文，Kubernetes 會自動幫你編碼存成 `data`。
- **Q：怎麼把 Secret 的某個值變成容器的環境變數？**
  A：在容器 `env` 下用 `valueFrom.secretKeyRef`，指定 Secret 的 `name` 與要取的 `key`。
- **Q：為什麼不該在 Pod manifest 直接 `value: <明文密碼>`？**
  A：manifest 常進 Git/CI/review，明文密碼會外洩且難清歷史；應改用 `secretKeyRef` 只保留參照。
- **Q：`kubectl describe secret` 為何不顯示值？這代表安全嗎？**
  A：那是 CLI 層的遮蔽，避免意外洩漏；但有權限者仍可用 `-o yaml` + `base64 -d` 或 `exec echo` 取回明文，並不代表安全。
- **Q：Secret 和使用它的 Pod 必須在同一個 namespace 嗎？**
  A：是。Secret 是 namespaced 資源，Pod 只能引用同 namespace 的 Secret。
- **Q：`kubectl get pods -w` 的 `-w` 是什麼？**
  A：watch/wait，持續輸出 Pod 狀態變化，方便等待容器啟動。
- **Q：如何當場證明 Secret 未加密？**
  A：`kubectl exec` 進容器 `echo $ENV_VAR`，會直接印出明文密碼。
- **Q：Opaque（generic）型別何時用？**
  A：存任意鍵值/檔案（如憑證）、不需特定 type 語意時；也是未指定 type 的預設。
- **Q：生產環境要怎麼真正保護 Secret？**
  A：啟用 encryption at rest（`EncryptionConfiguration`）或外接 KMS/Vault、以 RBAC 最小權限限制存取、開啟 audit、限制 `exec`。
- **Q：CKA/CKAD 會考 encryption at rest 的設定嗎？**
  A：不會。考試重點是建立/注入/檢視 Secret；加密設定不在動手範圍。

## 🧩 跨領域連結

- **雲原生 ↔ 資訊安全（機密管理）**：Secret 對應 secrets management 領域（Vault、KMS）；「編碼 ≠ 加密」「最小權限」「稽核」是共通原則。
- **Secret/RBAC ↔ 作業系統權限模型**：namespace + RBAC 類比 OS 的使用者/群組/檔案權限；環境變數注入類比 process 環境。
- **base64 ↔ 密碼學基礎**：釐清「編碼（encoding，可逆、無金鑰）vs 加密（encryption，需金鑰）」是密碼學入門的關鍵分野。
- **Config 與 Code 分離 ↔ 軟體工程 12-Factor App**：Secret/ConfigMap 是 12-Factor「在環境中存放 config」原則在 Kubernetes 的落地。
- **etcd ↔ 分散式系統一致性儲存**：Secret 落在 etcd（Raft 共識的 KV store），與 [[distributed-systems-advisor|分散式系統]] 的 replicated state 主題相接。

## 🔗 延伸學習路徑

- **下一步應學**：Secret 以 **volume mount** 注入檔案（相對於本講的 env 注入）、`imagePullSecrets`、`kubernetes.io/tls` 型別；接續 [[Lesson_7_Kubernetes_Persistent_Volumes|儲存（PV/PVC）]] 與部署主題。
- **推薦關鍵字**：`secretKeyRef`、`envFrom`、`EncryptionConfiguration`、`base64 -d`、`kubectl create secret generic/tls/docker-registry`、`--dry-run=client -o yaml`、RBAC `Role/RoleBinding`、External Secrets Operator、CSI Secrets Store。
- **相關資源**：Kubernetes 官方文件 Secrets 章節、「Encrypting Secret Data at Rest」官方指南、HashiCorp Vault、CKA/CKAD 課綱的 Configuration 主題。
- **在知識地圖中的位置**：屬「組態與資料注入」主題，承接 [[Lesson_5_Kubernetes_ConfigMaps|Lesson 5 ConfigMap]]、前接 [[Lesson_7_Kubernetes_Persistent_Volumes|Lesson 7 儲存]]；實務部署見本 repo [[gke-deploy]] skill。

## 🧾 實作範例（Manifests & kubectl）

### A. 宣告式建立 Secret（basic-auth）

`stringData`（收明文，人類友善；Kubernetes 自動 base64）：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret          # 與使用它的 Pod 必須同 namespace
type: kubernetes.io/basic-auth
stringData:
  password: alta3             # ASR 口播值，實際字串以影片畫面為準（見校正說明）
```

若改用 `data`（值需先 base64 編碼）：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
type: kubernetes.io/basic-auth
data:
  password: YWx0YTM=          # echo -n 'alta3' | base64
```

> 註：嚴格驗證下 `kubernetes.io/basic-auth` 慣例含 `username` 與 `password` 兩個 key；本講示範僅設 `password`。若遇驗證問題，可改用 `type: Opaque`。

建立與存檔提醒：

```bash
kubectl apply -f mysql-secret.yaml      # 或 kubectl create -f
# 講者提醒：改完 manifest 記得存檔，否則讀到舊內容
```

### B. 命令式建立（對照）

```bash
kubectl create secret generic mysql-secret \
  --from-literal=password=alta3
# --from-literal 對 ConfigMap 亦適用：
#   kubectl create configmap my-config --from-literal=LOG_LEVEL=info
```

### C. 檢視 Secret

```bash
kubectl get secrets
kubectl describe secret mysql-secret     # 只顯示 key（password）與 bytes，不顯示 value

# 「揭穿」：有權限者可還原明文（證明未加密）
kubectl get secret mysql-secret -o jsonpath='{.data.password}' | base64 -d
```

### D. 用 secretKeyRef 注入容器環境變數

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mysql-pod
spec:
  containers:
  - name: mysql
    image: mysql
    env:
    - name: MYSQL_ROOT_PASSWORD        # MySQL image 內建的環境變數約定
      valueFrom:
        secretKeyRef:
          name: mysql-secret           # 指向 Secret 名稱
          key: password                # 指向 Secret 裡的 key
```

反例（**請勿這樣做**——明文密碼進 manifest）：

```yaml
    env:
    - name: MYSQL_ROOT_PASSWORD
      value: alta3          # ❌ 明文密碼；會隨 Git/CI 外洩
```

換成 ConfigMap 只需把 `secretKeyRef` 改為 `configMapKeyRef`（凸顯可互換性）：

```yaml
      valueFrom:
        configMapKeyRef:
          name: my-config
          key: LOG_LEVEL
```

### E. 部署、觀察與驗證

```bash
kubectl create -f mysql-pod.yaml
kubectl get pods -w                     # -w = watch/wait，持續輸出狀態變化
# 等到 Running（容器不保證瞬間啟動）

kubectl exec mysql-pod -- printenv MYSQL_ROOT_PASSWORD
# 或： kubectl exec -it mysql-pod -- sh -c 'echo $MYSQL_ROOT_PASSWORD'
# 會印出明文密碼 → 驗證注入成功，同時證明 Secret 未加密
```

> 校正說明（ASR 修正）：本逐字稿為自動轉錄（ASR 誤把語言標記為 Chinese，實際為英文口語），本筆記已將明顯同音／誤植校正為標準術語：「kube control / cube control」→ **kubectl**、「config maps」→ **ConfigMap**、「mysql root password」→ **`MYSQL_ROOT_PASSWORD`**、「Kubectl gets secrets」→ **`kubectl get secrets`**、「dash w」→ **`-w`**。Secret 值「Alta three / all to three」為口播音，實際字串（可能為 `alta3`）以影片畫面為準，本筆記標記為不確定、未強行還原；`type: basic auth` 對應正式型別 **`kubernetes.io/basic-auth`**。逐字稿未口播講者全名，metadata 中的「Chad / 20 年教學經驗」取自本課程系列一貫自述，若與實際不符請以官方課程資訊為準；無法可靠還原的片段未予杜撰。
