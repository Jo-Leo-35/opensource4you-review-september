# Kubernetes Fundamentals Course Reference / Kubernetes 基礎課程參考資料

## Learning Status / 學習狀態

- **Purpose / 用途:** Supporting material for my ongoing Kubernetes and KubeRay learning / 作為持續學習 Kubernetes 與 KubeRay 的參考資料
- **Status / 狀態:** Actively studying and practicing; not yet a completed KubeRay code contribution / 正在學習與練習中；目前尚非已完成的 KubeRay 程式碼貢獻

The course contains ten lesson notes based on YouTube transcripts and SRT captions. Each lesson retains its original source link and attribution. According to the lesson metadata, the instructor is Chad, a CKA/CKAD instructor associated with Alta3 Academy.

這套課程包含 10 講由 YouTube 逐字稿與 SRT 字幕整理而成的筆記。每一講都保留原始影片連結與來源說明。依教材中的 metadata，講者是 Chad，為 CKA／CKAD 認證講師，課程與 Alta3 Academy 有關。

## Course and YouTube Sources / 課程與 YouTube 來源

| Lesson | Topic / 主題 | YouTube source / 影片來源 | Approx. duration / 約略長度 |
| ---: | --- | --- | ---: |
| 1 | [Kubernetes Architecture / Kubernetes 架構](references/lessons/Lesson_1_Kubernetes_Architecture.md) | [Video](https://www.youtube.com/watch?v=KhI5vjxNVb4) | 20:11 |
| 2 | [YAML and Manifests / YAML 與 Manifest](references/lessons/Lesson_2_Kubernetes_YAML_and_Manifests.md) | [Video](https://www.youtube.com/watch?v=-JtRpHr9bGQ) | 8:44 |
| 3 | [Pods and Namespaces / Pod 與 Namespace](references/lessons/Lesson_3_Kubernetes_Pods_and_Namespaces.md) | [Video](https://www.youtube.com/watch?v=7tdxlts-9qs) | 10:02 |
| 4 | [Resource Management / Requests 與 Limits](references/lessons/Lesson_4_Kubernetes_Resource_Management.md) | [Video](https://www.youtube.com/watch?v=t0-sj1mkdDg) | 12:11 |
| 5 | [Probes and ConfigMaps / Probe 與 ConfigMap](references/lessons/Lesson_5_Kubernetes_Probes_and_ConfigMaps.md) | [Video](https://www.youtube.com/watch?v=GjqvHl7Sj4A) | 26:57 |
| 6 | [Kubernetes Secrets](references/lessons/Lesson_6_Kubernetes_Secrets.md) | [Video](https://www.youtube.com/watch?v=_zoIC7ZmWNE) | 7:05 |
| 7 | [Logs and Labels / Log 與 Label](references/lessons/Lesson_7_Kubernetes_Logs_and_Labels.md) | [Video](https://www.youtube.com/watch?v=zSg82yiqLYU) | 14:46 |
| 8 | [Deployments](references/lessons/Lesson_8_Kubernetes_Deployments.md) | [Video](https://www.youtube.com/watch?v=fMIlW6GcN-U) | 16:33 |
| 9 | [Storage: PV and PVC / 儲存：PV 與 PVC](references/lessons/Lesson_9_Kubernetes_Storage_PV_PVC.md) | [Video](https://www.youtube.com/watch?v=4oiTq-DB6wg) | 15:38 |
| 10 | [Networking: Services and NetworkPolicy / 網路](references/lessons/Lesson_10_Kubernetes_Networking.md) | [Video](https://www.youtube.com/watch?v=qnAnBTQ3zb4) | 37:56 |

## Included Materials / 收錄內容

- [Course index / 教材索引](references/00-index.md)
- [Teaching workflow / 教學工作流](SKILL.md)
- [kubectl cheatsheet / kubectl 速查](references/kubectl-cheatsheet.md)
- [Troubleshooting guide / 排錯指南](references/troubleshooting.md)
- `references/lessons/`: ten detailed lesson notes / 10 講詳細筆記
- `templates/`: reusable Kubernetes YAML examples / 可重複使用的 Kubernetes YAML 範例
- `scripts/preflight-check.sh`: local environment preflight check / 本机环境预检查

These files document the material I am actively studying and the preparation work I am doing for future KubeRay contributions. They do not mean that all lessons or exercises have already been completed.

這些檔案記錄我目前正在學習的內容，以及為未來參與 KubeRay 貢獻所做的準備工作；但不表示已經完成全部課程或練習。
