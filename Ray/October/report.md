# Ray Monthly Contribution Report — October 2026

- **Contributor:** [Jo-Leo-35](https://github.com/Jo-Leo-35)
- **Project:** [Ray](https://github.com/ray-project/ray)
- **Reporting period:** October 1–8, 2026

## English Version

### Summary

From October 1 through October 8, I moved from onboarding to public technical work. I opened one detailed Ray issue about missing macOS task-memory metrics and independently reproduced and validated the behavior addressed by one community pull request.

| Contribution type | Count |
| --- | ---: |
| Pull requests authored | 0 |
| Pull requests independently validated | 1 |
| Issues opened | 1 |

### Independent Pull Request Validation

#### [ray-project/ray#66878 — Improve JSON read error context](https://github.com/ray-project/ray/pull/66878)

- Independently reproduced the malformed JSON error behavior using Ray 2.59.0 and pandas 2.3.3 across the Ray worker-to-driver exception boundary.
- Confirmed that the propagated error contained file context and the input path but lost the original parser detail.
- Verified that including the original exception in the outer message preserved the file context, file path, and parser detail.
- Shared the result in a public [validation comment](https://github.com/ray-project/ray/pull/66878#issuecomment-6076811929).

This was an independent technical validation and public comment, not an authored PR or a formal GitHub review approval.

### Issue and Technical Investigation

#### [ray-project/ray#66729 — Support task memory metrics on macOS](https://github.com/ray-project/ray/issues/66729)

- Reported that CPU-only Ray Data `map_batches` tasks complete on macOS but produce no USS memory samples because the current `MemoryProfiler` estimator is enabled only on Linux.
- Provided a standalone reproduction on Apple M5 with Ray 2.59.0. Both 64 MiB and 1 GiB allocations completed, while `max_uss_bytes.num_samples` remained zero and peak task USS was unavailable.
- Traced the behavior to the platform capability check and explained that missing samples also prevent the high-memory issue detector from evaluating the operator.
- Clarified that an empty aggregate means the measurement is unavailable, not that the task used zero memory.
- Compared CPU and Apple MPS memory observations and concluded that CPU USS support and MPS memory accounting should be treated as separate scopes.
- Proposed a narrow first fix: macOS-compatible CPU task sampling, tests, documentation, and explicit handling of unavailable measurements.

### Additional Learning and Next Step

- Watched [Ray in 30 min](https://www.youtube.com/watch?v=4Rbd_1Kb2qU) to reinforce Ray's core concepts and programming model.
- The next step is to evaluate the accuracy and overhead of macOS USS sampling. If feasible, the first small PR will cover CPU task sampling, tests, and documentation only; Apple MPS accounting will remain out of scope.

---

## 中文版本

### 摘要

10 月 1 日至 10 月 8 日，我從前期學習進入公開的技術工作：提出一個關於 macOS task 記憶體指標缺失的 Ray issue，並針對一個社群 PR 進行獨立重現與驗證。

| 貢獻類型 | 數量 |
| --- | ---: |
| 自行提交的 PR | 0 |
| 獨立驗證的 PR | 1 |
| 提出的 issue | 1 |

### PR 獨立驗證

#### [ray-project/ray#66878 — 改善 JSON 讀取錯誤的上下文資訊](https://github.com/ray-project/ray/pull/66878)

- 使用 Ray 2.59.0 與 pandas 2.3.3，獨立重現格式錯誤的 JSON 在 Ray worker 傳回 driver 時的例外行為。
- 確認傳回的錯誤包含檔案上下文與輸入路徑，但遺失原始 parser 的詳細錯誤。
- 驗證在外層訊息保留原始例外後，可以同時保留檔案上下文、路徑與 parser 細節。
- 將結果公開回覆在該 PR 的[驗證留言](https://github.com/ray-project/ray/pull/66878#issuecomment-6076811929)中。

這項工作是獨立技術驗證與公開留言，不宣稱為自行提交的 PR，也不宣稱為 GitHub 上的正式 approval review。

### Issue 與技術調查

#### [ray-project/ray#66729 — 在 macOS 上支援 task 記憶體指標](https://github.com/ray-project/ray/issues/66729)

- 回報純 CPU 的 Ray Data `map_batches` task 在 macOS 上可以完成，但因目前 `MemoryProfiler` estimator 只在 Linux 啟用，因此不會產生 USS 記憶體樣本。
- 在 Apple M5、Ray 2.59.0 環境提供獨立重現程式。64 MiB 與 1 GiB 配置皆能完成，但 `max_uss_bytes.num_samples` 仍為零，無法取得 task 峰值 USS。
- 追查到問題與平台能力檢查有關，並說明樣本缺失也會讓 high-memory issue detector 無法評估該 operator。
- 釐清空的統計聚合代表「量測不可用」，不是「實際使用零記憶體」。
- 比較 CPU 與 Apple MPS 的記憶體觀察結果，判斷 CPU USS 支援與 MPS 記憶體統計應拆成不同範圍處理。
- 建議第一個小型修正只處理 macOS CPU task 取樣、測試、文件，以及不可用量測的明確呈現。

### 其他學習與下一步

- 觀看 [Ray in 30 min](https://www.youtube.com/watch?v=4Rbd_1Kb2qU)，補充 Ray 核心概念與程式設計模型。
- 下一步會評估 macOS USS 取樣的準確度與額外負擔。若可行，第一個小型 PR 只涵蓋 CPU task 取樣、測試與文件；Apple MPS 統計不放進同一個 PR。

