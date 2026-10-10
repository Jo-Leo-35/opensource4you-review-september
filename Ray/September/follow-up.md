# Ray Verification and Handoff Checklist

This working checklist accompanies the [September report](report.md). It separates historical evidence from work that still needs execution.

- **Audit date:** October 10, 2026, approximately 10:05 Asia/Taipei (02:05 UTC).
- **Report repository:** [Jo-Leo-35/opensource4you-review-september](https://github.com/Jo-Leo-35/opensource4you-review-september).
- **Starting report commit:** `896a1d7`.
- **Current host:** Linux aarch64; Ray is not installed. This session checked public GitHub metadata, comments, and the PR diff. It did not run Ray, reproduce the reported behavior, or benchmark macOS.

## 1. Inventory and Attribution

| Item | Owner / my role | Status at audit | What is still pending |
| --- | --- | --- | --- |
| [PR #66878](https://github.com/ray-project/ray/pull/66878) | Yin-1022 authored it; Jo-Leo-35 posted an independent validation comment | Open, not merged | Revalidate the current revision and encoding cases |
| [Issue #66729](https://github.com/ray-project/ray/issues/66729) | Jo-Leo-35 authored the issue and recorded the experiments | Open; no issue comments; implementation checklist unchecked | Sampling benchmark, implementation, tests, documentation |
| [PR #66340](https://github.com/ray-project/ray/pull/66340) | xuwenyihust; related CUDA/NVML background | Open, not merged | No independent validation by Jo-Leo-35 established; not a contribution count |
| [Issue #66335](https://github.com/ray-project/ray/issues/66335) | xuwenyihust; related DGX Spark background | Open | Reference only; does not establish macOS or MPS behavior |

Public GitHub searches returned 0 authored PRs, 1 commented PR, 0 formally reviewed PRs, and 1 authored issue for the queries below. Searches are a snapshot, may lag indexing, and cannot establish private or unposted work. Any newly discovered activity must be checked against its actual timestamps before inclusion.

```text
repo:ray-project/ray is:pr author:Jo-Leo-35 created:2026-09-01..2026-10-11
repo:ray-project/ray is:pr commenter:Jo-Leo-35 updated:>=2026-09-01
repo:ray-project/ray is:pr reviewed-by:Jo-Leo-35 updated:>=2026-09-01
repo:ray-project/ray is:issue author:Jo-Leo-35 created:2026-09-01..2026-10-11
```

For the commented and reviewed queries, check the dates of the contributor's comments/reviews, not only the PR creation date. No formal review by Jo-Leo-35 appeared in #66878's review list.

## 2. Before the October 11 Submission

- [x] Consolidate Ray's early October work into `Ray/September/report.md`.
- [x] Use the required September 1–October 11 period and separately record the September 28 start date.
- [x] Correct the public PR validation date to October 9.
- [x] Distinguish an authored PR, independent validation comment, and formal GitHub review.
- [ ] Refresh the public activity and upstream status through the submission cutoff. Add only completed, evidenced work and update the snapshot timestamp.
- [ ] Confirm any additional October 9–11 work with dated links or execution logs; do not assume there was no activity merely because it is absent from the old report.
- [ ] If submitting both projects, consolidate KubeRay's existing October learning entry into its September report and update the README. Its learning progress and public activity were not re-audited here.
- [ ] Review the Markdown changes, then commit/publish the report update when requested. Local edits are not visible at the public repository URL until pushed.

The engineering tasks below are follow-ups, not prerequisites for honestly reporting the contributions already completed.

## 3. PR #66878: Current Revision and Known Evidence

| Field | Value at audit |
| --- | --- |
| Head SHA | `3f4b50164d014e0082d936246b4fae8d1811c6e1` |
| Base SHA reported by GitHub | `13097981b2537776062251793f8c5e7c9d930661` |
| Branch | `Yin-1022:fix-json-read-error-context` |
| My comment | [2026-10-09 07:52:19 UTC](https://github.com/ray-project/ray/pull/66878#issuecomment-6076811929) |
| Last review comment at audit | [2026-10-09 21:21:30 UTC / October 10, 05:21 Taipei](https://github.com/ray-project/ray/pull/66878#discussion_r4234649165) |

My comment records Ray 2.59.0 and pandas 2.3.3 and the following narrow result:

| Check | Before including original error text | After including original error text |
| --- | --- | --- |
| File context present | True | True |
| Input path present | True | True |
| Parser detail present | False | True |

The tested commit, full environment, script, and raw output are not recorded in that comment or this report repository. Do not infer its tested commit from the comment time. Later PR commits changed the implementation and tests.

### Questions requiring fresh execution

1. **Pandas JSONL invalid UTF-8:** [hikaru-212's comment](https://github.com/ray-project/ray/pull/66878#discussion_r4234649165) asks whether converting `UnicodeDecodeError` to plain `ValueError` is intentional. At the audited head, the [Pandas handler](https://github.com/ray-project/ray/blob/3f4b50164d014e0082d936246b4fae8d1811c6e1/python/ray/data/_internal/datasource/json_datasource.py#L230) catches `ValueError`, which includes `UnicodeDecodeError`. This is a static observation and another reviewer's reproduction, not a new runtime result from this session.
2. **Arrow fallback invalid UTF-8:** A bot [raised a worker/driver exception-type concern](https://github.com/ray-project/ray/pull/66878#discussion_r4229421649). The author [reported successful driver-side checks](https://github.com/ray-project/ray/pull/66878#discussion_r4229548791) and added assertions. Independently test the target environment before treating either claim as universal. This is distinct from the Pandas JSONL handler question.
3. **Parser diagnostics at the current head:** Repeat the original checks across an actual worker-to-driver boundary and cover both chunk-size estimation and subsequent reading.

### Suggested execution order

- [ ] Fetch the latest PR metadata, comments, and head SHA. If the head has changed, inspect the delta before testing.
- [ ] Prepare a separate Ray checkout and follow its contributor/environment instructions. Record the checked-out SHA and the imported Ray path/version/commit so tests do not silently use an unrelated installed wheel.
- [ ] Identify and record the comparison revision (prefer the PR merge base for an isolated before/after comparison). Keep dependencies and inputs identical.
- [ ] Run the current regression tests listed below on the PR checkout, then compare relevant behavior with the baseline.
- [ ] Add temporary reproduction cases for invalid UTF-8 in the first JSONL record (estimation) and after a valid record (reading). Record which code path was actually exercised; do not assume file layout guarantees a specific path.
- [ ] Inspect driver-visible exception type, underlying cause, input path, parser/encoding details, and traceback. Preserve raw output.
- [ ] Summarize what is reproducible at the recorded SHA and what remains environment-dependent. Prepare any proposed public reply for review; this handoff does not request posting it.

Existing tests at the audited head (run from a prepared Ray checkout):

```bash
python -m pytest -q python/ray/data/tests/datasource/test_json.py -k 'test_json_read_invalid_format_includes_path or test_json_read_invalid_utf8_includes_path or test_jsonl_read_invalid_format_includes_path'
```

Source: [test_json.py at the audited revision](https://github.com/ray-project/ray/blob/3f4b50164d014e0082d936246b4fae8d1811c6e1/python/ray/data/tests/datasource/test_json.py#L133). This is a proposed command, not an executed result. The JSONL regression covers malformed syntax; it does not by itself close the JSONL invalid-UTF-8 question.

### Upstream checks observed, not locally executed

- GitHub check runs for the audited SHA: DCO, disable-automerge, and Cursor Bugbot reported success.
- [Buildkite microcheck #55932](https://buildkite.com/ray-project/microcheck/builds/55932) reported success.
- [Buildkite release #110276](https://buildkite.com/ray-project/release/builds/110276) had a success status with the description “passed and blocked”; the docs status indicated a skipped build.
- These statuses do not establish independent local validation or complete platform coverage. The PR author's Windows baseline comparison is the author's result, not Jo-Leo-35's.

## 4. Issue #66729: macOS CPU USS Sampling

### Historical evidence already public

- [Issue body](https://github.com/ray-project/ray/issues/66729): macOS runs captured on October 5 using Ray 2.59.0, commit `dd83c3a703a5422d0b47f142cb380c6330817608`.
- CPU allocations of 64 MiB and 1 GiB completed, with zero task USS samples and a false platform-capability check.
- [Attached evidence archive](https://github.com/user-attachments/files/33063395/ray-macos-evidence-redacted.zip) is linked publicly. This organizing session did not download or execute it.
- Linux, master/nightly, Dashboard/Prometheus behavior, and a sampling-overhead benchmark were not covered by the original issue validation.

### Next steps and evidence required

- [ ] Read the issue's latest implementation checklist and relevant upstream code before designing a fix.
- [ ] Inspect the attached scripts/logs and recover the exact original environment and commands.
- [ ] On a macOS host, repeat the CPU-only baseline with the small allocation first; record sample count, public stats, versions, and allocation lifetime. Repeat on current master/nightly in a separate environment if supported.
- [ ] Use a comparable Linux run as a control and retain its exact revision and dependency versions. Linux results alone cannot validate macOS behavior.
- [ ] Evaluate a candidate macOS USS sampler with repeated baseline/allocation/release measurements at multiple allocation sizes. Record sampling latency, variability, and workload runtime with and without profiling. Treat USS accuracy as a measurement question, not a requirement to exactly match payload bytes.
- [ ] Define acceptable overhead and measurement semantics before adding support. Exercise unavailable/denied samples and process exit; preserve the distinction between unavailable and zero.
- [ ] If feasible, implement CPU-only sampling with targeted unit tests, a macOS allocation test, and platform/measurement documentation. Record a PR link only after a PR exists.
- [ ] Test high-memory detection separately with sufficient runtime, valid samples, and its actual threshold/interval. Absence of a warning in a short run is not evidence that detection works or fails.

Keep **Apple MPS accounting**, **CUDA/NVML accounting**, and the separate **unavailable-versus-zero presentation change** out of the first CPU sampling implementation. Do not relabel `phys_footprint` as USS or combine unrelated memory counters.

The current Linux host can support code inspection and a Linux control after setup. macOS sampling and MPS conclusions require appropriate Apple hardware; leave those tasks pending when that environment is unavailable.

## 5. What to Save After Each Validation

For each completed run, record the date/time, OS/architecture, Python and dependency versions, Ray SHA and import path, exact command, input fixture, expected and observed behavior, exit code, and raw-log location. Distinguish baseline results from PR results and local findings from upstream CI or other reviewers' reports.

Only update the submission report's completed-work claims after that evidence exists. Rechecking the same PR expands its description; it does not increase the count of distinct PRs validated.
