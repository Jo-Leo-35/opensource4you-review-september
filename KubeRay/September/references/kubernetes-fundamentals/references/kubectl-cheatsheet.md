# kubectl 指令速查（vendor-neutral）

> 對應 10 講課程的常用指令彙整。`<尖括號大寫>` 是佔位符，換成你的值。
> 常用簡寫：`po`=pods、`svc`=services、`ns`=namespaces、`cm`=configmap、`deploy`=deployment、`rs`=replicaset、`pv`/`pvc`、`netpol`=networkpolicy。

## 先記這兩個口訣

- **看不到資源** → 先問「我在對的 namespace 嗎？」：`-n <NS>` 指定，或 `-A` 一次看全部。
- **Pod 有問題** → `describe` 看 Events（找「起不來」的原因）→ `logs --previous` 看上一個實例（找「跑起來後掛掉」的原因）。

## 0. 動手前：定位環境（做任何變更前先跑）

```bash
kubectl config current-context          # 現在會打到哪個叢集？（最容易出包）
kubectl config get-contexts             # 有哪些叢集可切
kubectl config use-context <CONTEXT>    # 切換叢集
kubectl get nodes                       # 連得上嗎？幾個 node？
kubectl get ns                          # 有哪些 namespace
kubectl config set-context --current --namespace=<NS>   # 把預設 namespace 設成 <NS>，省得每次加 -n
```

## 1. 檢視（read-only，隨便下不會壞東西）

```bash
kubectl get pods                        # 目前 namespace 的 Pod（看 STATUS / RESTARTS）
kubectl get pods -o wide                # 多顯示 node、Pod IP
kubectl get pods -n <NS>                # 指定 namespace（看不到東西時 99% 是這個）
kubectl get pods -A                     # 所有 namespace（= --all-namespaces）
kubectl get pods -w                     # watch：持續輸出狀態變化（等 Running 用）
kubectl get all                         # 目前 namespace 的常見資源總覽
kubectl get deploy,rs,pods              # 觀察 Deployment→ReplicaSet→Pod 三層責任鏈

kubectl describe pod <POD>              # 最重要：看最底下的 Events（排錯第一站）
kubectl get pod <POD> -o yaml          # 匯出完整 YAML（含預設值），可當範本改

kubectl explain <RES>                   # 查某資源有哪些欄位（取代硬背）
kubectl explain pod.spec.containers     # 逐層往下鑽
kubectl explain pod.spec --recursive    # 一次展開整棵欄位樹
```

## 2. 建立 / 套用（宣告式優先）

```bash
kubectl apply -f <FILE>.yaml                       # 宣告式：不存在則建、已存在則更新（冪等）
kubectl apply -f <FILE>.yaml --dry-run=client -o yaml   # 套用前預覽（不真的送出）
kubectl diff -f <FILE>.yaml                        # 和叢集現況比對差異
kubectl apply -f <DIR>/                            # 套用整個資料夾
kubectl delete -f <FILE>.yaml                      # 用當初建立的 manifest 刪除（「我能造你就能毀你」）
kubectl delete <RES> <NAME>                        # 直接指定 類型+名稱 刪除（等效）
```

命令式快速建（考試 / 臨時測試好用，可 `--dry-run=client -o yaml` 反產生 YAML 骨架）：

```bash
kubectl run <POD> --image=<IMAGE>                          # 快速起一個 Pod
kubectl create namespace <NS>                              # 建 namespace
kubectl create deployment <NAME> --image=<IMAGE>          # 建 Deployment
kubectl create configmap <NAME> --from-file=<FILE>        # 從檔案建 ConfigMap
kubectl create configmap <NAME> --from-literal=K=V        # 從字面值建 ConfigMap
kubectl create secret generic <NAME> --from-literal=K=V   # 建 Secret
kubectl run <POD> --image=<IMAGE> --dry-run=client -o yaml > pod.yaml   # 反產生 YAML 骨架
```

## 3. 擴縮 / 更新 / 回滾（Deployment，Lesson 8）

```bash
kubectl scale deployment/<NAME> --replicas=<N>            # 手動擴縮
kubectl set image deployment/<NAME> <CONTAINER>=<IMAGE>   # 更新映像檔 → 觸發 rolling update
kubectl rollout status deployment/<NAME>                  # 即時看滾動更新進度
kubectl rollout history deployment/<NAME>                 # 看修訂版歷史
kubectl rollout undo deployment/<NAME>                    # 一鍵回滾到前一版（切回舊 ReplicaSet）
kubectl rollout undo deployment/<NAME> --to-revision=<N>  # 回滾到指定版本
kubectl rollout restart deployment/<NAME>                 # 強制重啟（重建所有 Pod）
```

## 4. 除錯（Lesson 3 / 5 / 7）

```bash
kubectl logs <POD>                       # 看容器 stdout/stderr
kubectl logs <POD> -c <CONTAINER>        # 多容器 Pod 指定容器（不加預設第一個容器）
kubectl logs <POD> --all-containers      # Pod 內所有容器的日誌
kubectl logs <POD> -f                    # follow：即時串流（Ctrl-C 結束）
kubectl logs <POD> --since=10s           # 只看最近 10 秒
kubectl logs <POD> --previous            # 看「上一個已崩潰的容器實例」→ CrashLoopBackOff 必用

kubectl exec -it <POD> -- sh             # 進容器開 shell（多容器加 -c <CONTAINER>）
kubectl exec <POD> -- printenv <VAR>     # 檢查注入的環境變數（驗證 Secret/ConfigMap）
kubectl cp ./<FILE> <POD>:/path/in/pod   # 從本機複製檔案進容器（雙向皆可）
kubectl port-forward <POD> <LOCAL>:<CONTAINER_PORT>   # 本機 port 轉發到容器（臨時測試，會佔用終端）

kubectl get events --sort-by=.lastTimestamp   # 依時間看整個 namespace 的事件
kubectl top nodes                        # 各 node CPU/memory 用量（需 metrics-server）
kubectl top pods -A                      # 各 Pod 用量（需 metrics-server）
```

## 5. 標籤 / 選取（Lesson 7）

```bash
kubectl get pods --show-labels           # 顯示每個 Pod 的所有 label
kubectl get pods -L <KEY>                # 把某個 label key 攤成獨立一欄（大寫 -L = 顯示）
kubectl get pods -l <KEY>=<VAL>          # selector：只撈符合的（小寫 -l = 篩選）
kubectl get pods -l <K1>=<V1>,<K2>=<V2>  # 多條件 AND（逗號分隔）
kubectl label pod <POD> <KEY>=<VAL>      # 新增 label
kubectl label pod <POD> <KEY>=<VAL> --overwrite   # 覆寫既有 label
kubectl label pod <POD> <KEY>-           # 刪除 label（key 後接減號）
kubectl delete pods -l <KEY>=<VAL>       # 用 selector 批次刪除
```

## 6. Namespace / 配額 / 資源（Lesson 3 / 4）

```bash
kubectl get ns
kubectl create namespace <NS>
kubectl get pods -n <NS>
kubectl describe resourcequota <NAME> -n <NS>   # 看 namespace 已用 / 上限
# metrics-server（kubectl top 前置）：
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl get apiservices | grep metrics          # 顯示 True 才能用 top
```

## 7. 儲存 / 網路（Lesson 9 / 10）

```bash
kubectl get pv                           # 叢集層級的 PersistentVolume
kubectl get pvc                          # namespace 層級的 Claim（看 STATUS 是否 Bound）
kubectl get svc                          # Service（看 TYPE / CLUSTER-IP / PORT）
kubectl describe svc <NAME>              # 看它追蹤到的 endpoints（後端 Pod IP）
kubectl get endpoints <NAME>            # 直接看 endpoints
kubectl get netpol                       # NetworkPolicy
kubectl expose deployment <NAME> --port=<PORT> --target-port=<TP>   # 命令式建 Service（預設 ClusterIP）
```

## 8. 清理（記得回到對的 namespace 再刪）

```bash
kubectl delete pod <POD>
kubectl delete deployment <NAME>
kubectl delete -f <FILE>.yaml            # 含 --- 多份文件會一起刪
kubectl delete all -l <KEY>=<VAL>        # 依 label 批次清（不含 pv/pvc/secret 等，需另外刪）
```
