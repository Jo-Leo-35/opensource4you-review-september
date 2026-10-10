# KubeRay Monthly Contribution Report — September 2026 / KubeRay 每月貢獻報告 — 2026 年 9 月

## English Version

- **Contributor:** [Jo-Leo-35](https://github.com/Jo-Leo-35)
- **Project:** [KubeRay](https://github.com/ray-project/kuberay)
- **Reporting period:** September 1–October 11, 2026
- **Fellowship start date:** September 28, 2026
- **Public activity checked as of:** October 10, 2026, 10:22 (Asia/Taipei, UTC+8)
- **Learning progress documented through:** October 8, 2026, based on the existing learning reports

### Summary

My KubeRay work is at the learning and preparation stage. I have forked KubeRay and organized the Kubernetes fundamentals needed for future issue reproduction and validation, but have not submitted an upstream PR. This September report consolidates the September 28–30 onboarding and October 1–8 learning entries for the first submission. Later learning progress has not yet been documented.

### Contribution Status

| Contribution type | Count |
| --- | ---: |
| Pull requests authored and submitted upstream | 0 |
| Pull requests independently validated | 0 |
| Formal GitHub PR reviews submitted | 0 |
| Issues opened | 0 |

### Pull Requests

- **Fork:** [Jo-Leo-35/kuberay](https://github.com/Jo-Leo-35/kuberay), created on October 8, 2026.
- **Current stage:** Repository familiarization and preparation for reproduction work. No upstream PR has been submitted; the fork itself is not counted as a code contribution.
- **Workflow reference:** Chi-Sheng Liu's [Git workflow guide](https://chishengliu.com/zh-tw/posts/opensource-git-operations/) is a reference for setting up the fork and upstream relationship and preparing a separate working branch before a future change.

### Reviewed PR / Independent Validation

No reviewed or independently validated KubeRay PR is recorded for this reporting period. I have not yet completed a KubeRay-specific engineering validation to report.

### Other Contributions

#### Kubernetes Learning and Preparation

- Studied Kubernetes architecture, Pods, Namespaces, resource requests and limits, configuration, Deployments, storage, networking, and troubleshooting.
- Organized a [public Kubernetes Fundamentals reference](references/kubernetes-fundamentals/README.md) containing 31 files: ten lesson notes with sources, command and troubleshooting references, a preflight script, and YAML examples.
- Began connecting Kubernetes concepts to KubeRay resources and controller workflows at a conceptual level.

These are ongoing learning and preparation activities. The reference describes the material being studied; it does not mean every lesson, script, or exercise has been completed or verified.

### Pending Validation and Next Steps

- Continue the selected lessons and hands-on exercises, recording actual commands and outcomes.
- Read KubeRay's contributor documentation and prepare the development environment for the fork.
- Select a small KubeRay issue, reproduce it at a recorded commit, and save environment details and logs before proposing a focused change.
- Add any completed October 9–11 learning or technical work before the deadline. Only count an upstream PR or public validation after it exists.

### References

- [Kubernetes Fundamentals learning material](references/kubernetes-fundamentals/README.md), retained in its existing format
- [October report placeholder](../October/report.md); early October learning is included here and should not be counted again next cycle.

---

## 中文版本

- **貢獻者：** [Jo-Leo-35](https://github.com/Jo-Leo-35)
- **專案：** [KubeRay](https://github.com/ray-project/kuberay)
- **報告範圍：** 2026 年 9 月 1 日至 10 月 11 日
- **加入 fellowship 日期：** 2026 年 9 月 28 日
- **公開活動查核截至：** 2026 年 10 月 10 日 10:22（Asia/Taipei，UTC+8）
- **已記錄的學習進度截至：** 2026 年 10 月 8 日，依既有學習報告整理

### 摘要

目前 KubeRay 的工作處於學習與準備階段。我已 fork KubeRay，並整理未來重現與驗證問題所需的 Kubernetes 基礎，但尚未向上游提交 PR。這份 September 報告合併了 9 月 28–30 日的入門與 10 月 1–8 日的學習紀錄，作為首次繳交內容。之後的學習進度尚未補入。

### 貢獻狀態

| 貢獻類型 | 數量 |
| --- | ---: |
| 自行撰寫並向上游提交的 PR | 0 |
| 獨立驗證的 PR | 0 |
| 在 GitHub 提交的正式 PR review | 0 |
| 提出的 issue | 0 |

### Pull Requests

- **Fork：** [Jo-Leo-35/kuberay](https://github.com/Jo-Leo-35/kuberay)，建立於 2026 年 10 月 8 日。
- **目前階段：** 熟悉 repository，並為後續問題重現做準備。尚未向上游提交 PR；fork 本身不計為程式碼貢獻。
- **流程參考：** 以劉奇聖的[開發開源專案常用的 Git 操作指南](https://chishengliu.com/zh-tw/posts/opensource-git-operations/)作為參考，了解 fork 與 upstream 的設定關係，以及未來修改前如何準備獨立工作分支。

### Reviewed PR／獨立驗證

本期尚無 KubeRay PR 審閱或獨立驗證紀錄，也尚未完成可列入報告的 KubeRay 專屬工程驗證。

### 其他貢獻

#### Kubernetes 學習與準備

- 學習 Kubernetes 架構、Pod、Namespace、resource request／limit、設定管理、Deployment、儲存、網路與問題排查。
- 整理包含 31 份檔案的[公開 Kubernetes Fundamentals 參考資料](references/kubernetes-fundamentals/README.md)：包括 10 講附來源的課程筆記、指令與排錯資料、環境預檢腳本，以及 YAML 範例。
- 開始從概念上連結 Kubernetes 基礎與 KubeRay resource、controller 工作流程。

這些是持續中的學習與準備活動。參考資料呈現正在學習的內容，不代表所有課程、腳本或練習都已完成或驗證。

### 待驗證項目與下一步

- 繼續選定的課程與實作練習，記錄實際執行的指令與結果。
- 閱讀 KubeRay contributor 文件，為 fork 準備開發環境。
- 選擇一個小型 KubeRay issue，在明確記錄的 commit 上重現，保存環境資訊與日誌後，再提出範圍明確的修改。
- 截止前補上 10 月 9–11 日已完成的學習或技術工作。上游 PR 或公開驗證實際存在後，才計入相應貢獻。

### 參考資料

- [Kubernetes Fundamentals 學習資料](references/kubernetes-fundamentals/README.md)，保留既有格式
- [October 預留報告](../October/report.md)；10 月初的學習已納入本期，下期不重複計算。
