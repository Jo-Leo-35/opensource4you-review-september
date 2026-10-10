# Ray Monthly Contribution Report — September 2026 / Ray 每月貢獻報告 — 2026 年 9 月

## English Version

- **Contributor:** [Jo-Leo-35](https://github.com/Jo-Leo-35)
- **Project:** [Ray](https://github.com/ray-project/ray)
- **Reporting period:** September 1–October 11, 2026
- **Fellowship start date:** September 28, 2026
- **Public activity checked as of:** October 10, 2026, 10:22 (Asia/Taipei, UTC+8)

### Summary

I progressed from onboarding to investigating macOS task memory metrics and independently validating a community PR. I have forked Ray for investigation and local validation, but have not submitted my own PR upstream. This September report includes early October work as required by the fellowship announcement; work after the snapshot time is not yet included.

### Contribution Status

| Contribution type | Count |
| --- | ---: |
| Pull requests authored and submitted upstream | 0 |
| Pull requests independently validated | 1 |
| Formal GitHub PR reviews submitted | 0 |
| Issues opened | 1 |

### Pull Requests

- **Fork:** [Jo-Leo-35/ray](https://github.com/Jo-Leo-35/ray), created on October 8, 2026.
- **Current stage:** Investigation and local validation; no authored upstream PR yet. Fork-based work and local experiments are preparation/investigation, not submitted PRs.
- **Workflow reference:** Chi-Sheng Liu's [Git workflow guide](https://chishengliu.com/zh-tw/posts/opensource-git-operations/). For the eventual change, I will use a separate working branch, keep it aligned with upstream, preserve validation evidence, and submit a focused PR once ready, including commit sign-off where the project requires it.

### Reviewed PR / Independent Validation

#### [#66878 — Improve JSON read error context](https://github.com/ray-project/ray/pull/66878)

- **Author / status:** Yin-1022; open and not merged at the snapshot.
- **My contribution:** [Public validation comment](https://github.com/ray-project/ray/pull/66878#issuecomment-6076811929), posted October 9, 2026, 15:52 (Asia/Taipei).
- Using Ray 2.59.0 and pandas 2.3.3, I reproduced a parsing error that retained file context and the input path but lost parser details across the worker-to-driver boundary. Including the original exception text in the outer message made all three checks pass.
- This was an independent validation comment, not an authored PR or a formal approval. The comment does not identify the tested commit or contain full logs, so validation of the current PR revision remains pending.

### Other Contributions

#### [#66729 — Support task memory metrics on macOS](https://github.com/ray-project/ray/issues/66729)

- **Role / status:** Issue author; opened October 5, 2026; still open at the snapshot.
- Recorded CPU-only `map_batches` experiments on Apple M5, macOS 26.6, Python 3.12.14, and Ray 2.59.0. Both 64 MiB and 1 GiB allocations completed two tasks, but `max_uss_bytes.num_samples` remained zero.
- Traced the behavior to the Linux-only sampling capability check and explained why the high-memory detector skips operators without samples. Clarified that unavailable measurements do not mean zero memory usage.
- Added a separate CPU/MPS comparison to explain why CPU USS support and MPS accounting need separate scopes. The MPS experiment ran outside Ray and does not demonstrate Ray MPS support.
- Published reproduction details and an [evidence archive](https://github.com/user-attachments/files/33063395/ray-macos-evidence-redacted.zip). The original runs were captured on October 5, before the fork was created. Linux, master/nightly, and Dashboard/Prometheus were not tested in those runs; MPS observations were one run per device.

#### Learning and Preparation

- Learned Ray's contribution workflow and how to document reproducible issues with environment details and observed versus expected behavior.
- Studied Ray and Ray Data concepts and watched [Ray in 30 min](https://www.youtube.com/watch?v=4Rbd_1Kb2qU), as recorded in my earlier report.

### Pending Validation and Next Steps

- Revalidate #66878 at a recorded commit, including parser details and JSON/JSONL invalid UTF-8 behavior. A [Pandas JSONL exception-subtype question](https://github.com/ray-project/ray/pull/66878#discussion_r4234649165) was raised by another reviewer; I have not independently verified it.
- Benchmark macOS CPU USS sampling accuracy and overhead, with repeated allocation measurements and a Linux control where feasible.
- If feasible, prepare a small CPU-sampling change with tests and documentation. MPS, CUDA/NVML, and a broader unavailable-versus-zero presentation change remain separate follow-ups.
- Refresh dated evidence and contribution counts before the October 11 deadline. Pending work is not counted as completed work.

### References

- [Detailed validation evidence, current PR revision, and execution checklist](references/follow-up.md)
- [October report placeholder](../October/report.md); the October 9 validation is included here and should not be counted again next cycle.

---

## 中文版本

- **貢獻者：** [Jo-Leo-35](https://github.com/Jo-Leo-35)
- **專案：** [Ray](https://github.com/ray-project/ray)
- **報告範圍：** 2026 年 9 月 1 日至 10 月 11 日
- **加入 fellowship 日期：** 2026 年 9 月 28 日
- **公開活動查核截至：** 2026 年 10 月 10 日 10:22（Asia/Taipei，UTC+8）

### 摘要

我從入門學習進展到 macOS task 記憶體指標調查，以及社群 PR 的獨立驗證。已 fork Ray 進行問題調查與本機驗證，但尚未向上游提交自己的 PR。依 fellowship 公告，這份 September 報告包含 10 月初的工作；查核時間之後的工作尚未納入。

### 貢獻狀態

| 貢獻類型 | 數量 |
| --- | ---: |
| 自行撰寫並向上游提交的 PR | 0 |
| 獨立驗證的 PR | 1 |
| 在 GitHub 提交的正式 PR review | 0 |
| 提出的 issue | 1 |

### Pull Requests

- **Fork：** [Jo-Leo-35/ray](https://github.com/Jo-Leo-35/ray)，建立於 2026 年 10 月 8 日。
- **目前階段：** 問題調查與本機驗證，尚未向上游提交自己撰寫的 PR。Fork 中的工作與本機實驗歸入準備及調查，不計為已提交的 PR。
- **流程參考：** 劉奇聖的[開發開源專案常用的 Git 操作指南](https://chishengliu.com/zh-tw/posts/opensource-git-operations/)。後續變更會使用獨立工作分支、同步上游進度並保留驗證證據，準備完成後再提交範圍明確的 PR；若專案要求，也會為 commit 加上 sign-off。

### Reviewed PR／獨立驗證

#### [#66878 — 改善 JSON 讀取錯誤的上下文資訊](https://github.com/ray-project/ray/pull/66878)

- **作者／狀態：** Yin-1022；查核時仍為 open，尚未合併。
- **我的貢獻：** [公開驗證留言](https://github.com/ray-project/ray/pull/66878#issuecomment-6076811929)，發表於 2026 年 10 月 9 日 15:52（Asia/Taipei）。
- 使用 Ray 2.59.0 與 pandas 2.3.3，重現解析錯誤從 worker 傳到 driver 時，保留檔案上下文與輸入路徑，卻遺失 parser 詳細訊息的行為。在外層訊息加入原始例外文字後，三項檢查皆通過。
- 這是獨立驗證留言，不是自行提交的 PR，也不是正式 approval。留言未記錄受測 commit 或完整日誌，因此最新版 PR 仍待重新驗證。

### 其他貢獻

#### [#66729 — 在 macOS 上支援 task 記憶體指標](https://github.com/ray-project/ray/issues/66729)

- **角色／狀態：** Issue 作者；2026 年 10 月 5 日提出，查核時仍為 open。
- 記錄 Apple M5、macOS 26.6、Python 3.12.14、Ray 2.59.0 上的純 CPU `map_batches` 實驗。64 MiB 與 1 GiB 配置都完成兩個 task，但 `max_uss_bytes.num_samples` 仍為零。
- 追查到僅支援 Linux 的取樣能力檢查，並說明 high-memory detector 為何跳過沒有樣本的 operator。釐清量測不可用不代表實際記憶體用量為零。
- 補充獨立的 CPU／MPS 比較，說明 CPU USS 支援與 MPS 記憶體統計應分開處理。MPS 實驗在 Ray 之外執行，不能作為 Ray 支援 MPS 的證據。
- 公開重現步驟與[證據壓縮檔](https://github.com/user-attachments/files/33063395/ray-macos-evidence-redacted.zip)。原始實驗記錄於 10 月 5 日，早於 fork 建立日期；當時未測試 Linux、master／nightly 或 Dashboard／Prometheus，MPS 觀察則為每個裝置各執行一次。

#### 學習與準備

- 學習 Ray 貢獻流程，以及如何整理包含環境資訊、實際與預期行為的可重現 issue。
- 學習 Ray 與 Ray Data 概念，並觀看 [Ray in 30 min](https://www.youtube.com/watch?v=4Rbd_1Kb2qU)，此項已記錄在先前報告中。

### 待驗證項目與下一步

- 記錄受測 commit，重新驗證 #66878 的 parser 訊息與 JSON／JSONL 無效 UTF-8 行為。另一位 reviewer 提出了 [Pandas JSONL 例外子型別問題](https://github.com/ray-project/ray/pull/66878#discussion_r4234649165)，我尚未獨立驗證。
- 以重複配置實驗評估 macOS CPU USS 取樣準確度與額外負擔，並在可行情況下加入 Linux 對照。
- 若可行，準備小範圍的 CPU 取樣變更、測試與文件。MPS、CUDA／NVML，以及更廣泛的「不可用與零值」呈現調整另行處理。
- 在 10 月 11 日截止前更新具日期的證據與貢獻數量。待辦項目不計為已完成工作。

### 參考資料

- [詳細驗證證據、目前 PR 版本與執行清單](references/follow-up.md)
- [October 預留報告](../October/report.md)；10 月 9 日的驗證已納入本期，下期不重複計算。
