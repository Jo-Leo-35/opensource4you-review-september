# Ray Monthly Contribution Report — September 2026

- **Contributor:** [Jo-Leo-35](https://github.com/Jo-Leo-35)
- **Project:** [Ray](https://github.com/ray-project/ray)
- **Required reporting period:** September 1–October 11, 2026
- **Fellowship start date:** September 28, 2026
- **Public activity checked through:** October 10, 2026, 10:05 (Asia/Taipei, UTC+8)
- **Submission deadline:** October 11, 2026, 23:59; first selection: October 15, 2026

Per the fellowship announcement, contributions through October 11 belong in this September report. I joined on September 28. This is a progress snapshot before the deadline; it does not claim completion of future work on October 10–11.

## Summary

I progressed from onboarding to a reproducible Ray Data issue and an independent validation of a community PR. My work focused on task memory visibility on macOS and preserving JSON parser diagnostics across the worker-to-driver exception boundary.

| Contribution type | Count | Evidence |
| --- | ---: | --- |
| Pull requests authored | 0 | No authored Ray PR found in the reporting-period search |
| Pull requests independently validated | 1 | [Validation comment on #66878](https://github.com/ray-project/ray/pull/66878#issuecomment-6076811929) |
| Formal GitHub PR reviews submitted | 0 | The validation above was a conversation comment |
| Issues opened | 1 | [Issue #66729](https://github.com/ray-project/ray/issues/66729) |

Counts reflect the public records checked at the snapshot time. Pending investigations below are not additional completed contributions.

## Pull Requests

I have not authored a Ray PR during this reporting period. The macOS sampling implementation is still planned.

## Reviewed PR / Independent Validation

### [#66878 — Improve JSON read error context](https://github.com/ray-project/ray/pull/66878)

- **PR author:** [Yin-1022](https://github.com/Yin-1022)
- **Upstream status at the snapshot:** Open; not merged.
- **My public contribution:** [Validation comment](https://github.com/ray-project/ray/pull/66878#issuecomment-6076811929), posted October 9, 2026, 15:52 (Asia/Taipei).
- **Environment recorded in my comment:** Ray 2.59.0 and pandas 2.3.3.

I independently reproduced a loss of parser details when a JSONL parsing failure crossed the Ray worker-to-driver boundary. The error retained the file context and path, but the parser-detail check was false. After including the original exception text in the outer message, all three checks were true. I shared the result with the PR author.

This contribution is an independent reproduction and validation comment, not an authored PR or a formal GitHub approval. The comment does not record the tested commit or provide a full test log, so it does not establish validation of the current PR revision.

**Follow-up:** The PR has since changed. Revalidation of the current revision, including JSON/JSONL invalid UTF-8 behavior, remains pending. Another reviewer raised a [Pandas JSONL exception-subtype question](https://github.com/ray-project/ray/pull/66878#discussion_r4234649165); that finding belongs to the reviewer and is not counted as my contribution.

## Other Contributions

### [#66729 — Support task memory metrics on macOS](https://github.com/ray-project/ray/issues/66729)

- **Role:** Issue author and technical investigator.
- **Opened:** October 5, 2026.
- **Upstream status at the snapshot:** Open; implementation checklist still incomplete.
- **Recorded environment:** Apple M5, macOS 26.6, Python 3.12.14, Ray 2.59.0.
- **Evidence:** [Issue reproduction and observations](https://github.com/ray-project/ray/issues/66729), with an attached [scripts and logs archive](https://github.com/user-attachments/files/33063395/ray-macos-evidence-redacted.zip).

I reported that CPU-only Ray Data `map_batches` tasks complete on macOS without producing task USS memory samples. Both the 64 MiB and 1 GiB allocation runs completed two tasks, while `max_uss_bytes.num_samples` remained zero. I traced the limitation to the Linux-only capability check and documented that the high-memory detector skips operators without samples.

I clarified that an empty aggregate represents an unavailable measurement, rather than measured zero memory usage. A separate CPU/MPS experiment showed why CPU USS sampling and MPS accounting need distinct treatment. The MPS experiment ran outside Ray and does not demonstrate Ray MPS support.

The next implementation step is to evaluate macOS CPU USS sampling accuracy and overhead, then add sampling support, tests, and documentation if feasible. Clearer unavailable-versus-zero presentation is a separate follow-up. Apple MPS and CUDA/NVML accounting are outside this first implementation scope.

**Limits of the recorded evidence:** Linux, master/nightly, and Dashboard/Prometheus behavior were not tested in the issue's original validation. The MPS observations were one run per device, not a comprehensive benchmark.

### Learning and Onboarding

- Became familiar with Ray's contribution workflow and practiced documenting environment details, reproduction steps, and observed versus expected behavior.
- Studied Ray and Ray Data concepts to identify a focused first contribution.
- Watched [Ray in 30 min](https://www.youtube.com/watch?v=4Rbd_1Kb2qU), as recorded in my earlier report.

## Pending Work

| Priority | Item | Completion evidence still needed |
| --- | --- | --- |
| Before submission | Refresh this report through the October 11 cutoff | Dated public links for any new work; updated statuses and counts |
| Next PR validation | Recheck #66878 at a recorded commit | Environment, commands, logs, and driver-visible parser/encoding results |
| Next investigation | Benchmark macOS CPU USS sampling for #66729 | Repeated allocation measurements, baseline comparison, and sampling overhead |
| After feasibility is established | Implement a small CPU-only sampling change | Platform/error-handling tests, documentation, and a PR link if submitted |

The detailed [verification and handoff checklist](follow-up.md) records the current PR revision, unresolved questions, and next steps. These tasks do not need to be represented as completed to report the contributions already made.

## Evidence and Date Notes

- The previous October report labeled the PR validation as part of October 1–8. GitHub records the validation comment at **2026-10-09 07:52:19 UTC**, so this report uses October 9.
- The original issue runs are recorded as October 5. The October 10 snapshot is a public-record check, not a new execution of those experiments.
- This report consolidates the earlier Ray September and October entries for the first fellowship submission. The [October entry](../October/report.md) now points here to prevent duplicate counting.
