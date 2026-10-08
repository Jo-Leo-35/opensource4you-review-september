# Kubernetes 排錯手冊（vendor-neutral）

> 適用於任何 Kubernetes 叢集（本機 minikube/kind、自管、雲上皆可）。
> 雲平台專屬問題（LoadBalancer 拿不到外部 IP、Ingress、雲端權限/IAM、Workload Identity）請見 `gke-deploy` 技能。

## 兩個口訣（先記這兩句，能先解掉一半的問題）

1. **看不到資源** → 先問「我在對的 namespace 嗎？」：`-n <NS>` 指定，或 `-A` 一次看全部（見症狀 0）。
2. **Pod 有問題** → `describe` 看 Events（找「起不來」的原因）→ `logs --previous` 看上一個實例（找「跑起來後掛掉」的原因）（見排錯黃金三步）。

## 排錯黃金三步（先做這個）

```bash
kubectl get pods                 # STATUS 是什麼？RESTARTS 高嗎？
kubectl describe pod <POD>       # 看最底下 Events —— 找「起不來」的原因
kubectl logs <POD> --previous    # 看上一個崩潰實例的 stdout/stderr —— 找「跑起來後掛掉」的原因
```
**分工**：`describe` 看 Events（排程 / 拉映像檔 / 掛載 / quota），`logs` 看應用輸出（程式自己噴的錯）。
多容器 Pod 用 `-c <CONTAINER>` 指定。

---

## 症狀 0：`kubectl get pods` 說 "No resources found"

**最常見、也最不像 bug 的陷阱。** 你多半只是沒在對的 namespace 看。

```bash
kubectl get pods -n <NS>      # 到你建立資源的那個 namespace 看
kubectl get pods -A           # 一次看所有 namespace，確認它到底在哪
```
> 對應 Lesson 3：`default` 只是「字面上叫 default」的一個 namespace；用 `metadata.namespace` 或 `-n` 建到別處的資源，不加 `-n` 就看不到。

---

## 症狀 1：Pod 卡在 `Pending`

**含義**：scheduler 還沒把 Pod 排到任何 node（或排不出去）。看 `describe` 的 Events。

| Events 訊息關鍵字 | 原因 | 怎麼修 |
|---|---|---|
| `Insufficient cpu` / `Insufficient memory` | 沒有 node 有足夠資源滿足 `requests` | 調低 `resources.requests`（Lesson 4）、或加 node/擴容 |
| `didn't match node selector` / affinity | `nodeSelector`/affinity 沒有 node 符合 | 檢查 `nodeSelector` 的 label（如 `kubernetes.io/hostname`）是否真的存在該 node（Lesson 9） |
| `pod has unbound immediate PersistentVolumeClaims` | PVC 沒綁到 PV | 見症狀 6 |
| `exceeded quota` | 超過 namespace 的 ResourceQuota | 看 `kubectl describe resourcequota -n <NS>`，降低 requests/limits 或請管理者放寬（Lesson 4） |

---

## 症狀 2：`ImagePullBackOff` / `ErrImagePull`

**含義**：kubelet 拉不到映像檔。**本課反覆強調：image 名稱是最容易打錯的欄位。**

檢查順序：
1. **拼字 / tag**：`image:` 名稱、tag 是否正確？（`nginx:1.27` 而不是 `nignx`）。看 `describe` Events 會寫 `not found` 還是 `unauthorized`。
2. **`not found`** → 映像檔或 tag 不存在。確認 registry 上真的有這個 tag。
3. **`unauthorized` / `pull access denied`** → 私有 registry 需要 imagePullSecret，或你沒登入。
4. 對照 Lesson 2 的「三大打字精準度失敗點」。

---

## 症狀 3：`CrashLoopBackOff`

**含義**：容器起得來，但一跑就掛，K8s 反覆重啟、越等越久（back-off）。

```bash
kubectl logs <POD> --previous     # 關鍵！當前容器已重啟，錯誤線索留在「上一個」實例
kubectl describe pod <POD>        # 確認是 crash 還是被 liveness probe 殺
```
常見根因：
- **應用自己啟動就報錯**：設定檔缺失、連不到相依服務、環境變數沒給。`logs --previous` 會直接告訴你。
- **mountPath 覆蓋了目錄**（Lesson 5 經典）：把 volume 掛到 `/etc/nginx` 這種既有目錄 → 原本的設定檔被蓋掉 → 應用找不到檔案而崩潰。**只想放單一檔案改用 `subPath`。**
- **Liveness probe 太兇**：`initialDelaySeconds` 太短，應用還在暖機就被探測判失敗而殺掉。放寬時間參數（Lesson 5）。
- **command/args 錯誤或容器沒有長駐行程**：主行程結束容器就退出。

---

## 症狀 4：`OOMKilled`（RESTARTS 增加、describe 顯示 Reason: OOMKilled）

**含義**：容器用的 memory 超過 `limits.memory`，被核心殺掉。

- 調高 `resources.limits.memory`（Lesson 4），或修掉應用的記憶體洩漏。
- 注意 `limits` 是硬上限；`requests` 只是排程保證下限。`limits ≥ requests` 是鐵律。

---

## 症狀 5：Pod 是 `Running` 但 `READY` 是 `0/1`（或 `n/m`）

**含義**：容器在跑，但 **readiness probe 沒通過**，所以還沒被加進 Service 的流量目標。

```bash
kubectl describe pod <POD>       # 看 readiness probe 失敗的 Events
kubectl logs <POD>               # 看應用是否還沒真的就緒
```
- 檢查 readiness probe 的 `path`/`port` 對不對、`initialDelaySeconds` 是否夠長（Lesson 5）。
- 多容器 Pod：`2/2` 才是全就緒；`1/2` 代表有一個容器沒 ready。

---

## 症狀 6：PVC 一直 `Pending`（沒 Bound）

**含義**：PVC 找不到可綁定的 PV。

```bash
kubectl get pvc          # STATUS 是 Pending 還是 Bound？
kubectl get pv           # 有沒有相容的 PV？
kubectl describe pvc <NAME>
```
檢查（Lesson 9）：
- **`storageClassName` 要一致**：PVC 靠相同的 storageClassName 匹配 PV。
- **`accessModes` 要相容**：例如兩邊都 `ReadWriteOnce`。
- **容量**：PVC 要求的 `requests.storage` 不能超過 PV 的 `capacity`。
- 若用動態佈建（dynamic provisioning），確認該 StorageClass 存在且有 provisioner；本課的 manual 範例則需先手動建好 PV。

---

## 症狀 7：連不上服務（Pod 之間、或對外）

排查順序（Lesson 10）：
```bash
kubectl get svc <NAME>            # 有 CLUSTER-IP 嗎？TYPE 對嗎？
kubectl describe svc <NAME>       # Endpoints 有值嗎？（空的代表沒選到任何後端 Pod）
kubectl get endpoints <NAME>
```
- **Endpoints 是空的** → Service 的 `selector` label 和 Pod 的 label **對不上**。這是最常見原因。
- **`port` vs `targetPort` 搞混**：`port` 是 Service 自己開的埠；`targetPort` 是後端容器的埠。連 Service 用 `port`。
- **用 Service 名稱而非 Pod IP**：Pod IP 是移動目標，服務發現要用 Service 名稱（同 namespace 直接用名稱，跨 namespace 用 `<svc>.<ns>.svc.cluster.local`）。
- **被 NetworkPolicy 擋**：見症狀 8。
- 臨時繞過驗證應用本身：`kubectl port-forward <POD> 8080:<containerPort>` 直接打 Pod。

---

## 症狀 8：明明服務正常，流量卻被擋（懷疑 NetworkPolicy）

```bash
kubectl get netpol -n <NS>
kubectl describe netpol <NAME> -n <NS>
```
檢查（Lesson 10）：
- **default-deny 現象**：一旦某 Pod 被任一 NetworkPolicy 的 `podSelector` 選中且列了 `policyTypes`，未明列放行的流量就全擋。逐步加白名單。
- **OR / AND 陷阱**：`from` 清單裡**分開的 `-` 元素是 OR**；把 `namespaceSelector` 與 `podSelector` 寫在**同一個 `-` 下是 AND**（要同時滿足）。這常導致「以為放行了其實沒有」。
- **Egress 也要放**：如果 policyTypes 含 `Egress`，出向流量（含 DNS）也需明列，否則連 DNS 解析都會失敗。
- 記得叢集的 CNI 要支援 NetworkPolicy，否則寫了也不生效。

---

## 症狀 9：`kubectl top` 報 "metrics API not available"

- 還沒裝 metrics-server（Lesson 4）：
  ```bash
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  kubectl get apiservices | grep metrics    # 等到顯示 True
  ```

---

## 症狀 10：手改的設定 / 資料，Pod 重建後不見了

**這不是 bug，是設計**（Lesson 5）。容器是 stateless：`exec` 進去改的檔案、`cp` 進去的東西，Pod 一重建就回到映像檔的原始狀態。

- 要讓**設定**存活 → 用 ConfigMap（掛成 volume 或注入 env）。
- 要讓**資料**存活 → 用 PV/PVC。
- 要讓**Pod 本身**在被刪後自動回來 → 用 Deployment，別跑裸 Pod（Lesson 8）。

---

## 通用心法

1. **先 `describe` 再 `logs`**：Events 告訴你「為什麼起不來」，logs 告訴你「起來後為什麼掛」。
2. **看不到就換 namespace**：`-n <NS>` / `-A`。
3. **不確定欄位就 `kubectl explain`**，不要憑印象亂寫。
4. **改之前先 `--dry-run=client -o yaml` 或 `kubectl diff`**，看清楚再送。
5. **一次只改一個變因**，改完馬上 `get pods -w` 觀察，才知道是哪一步生效/壞掉。
