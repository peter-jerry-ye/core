# Review: Testing & Diagnostics

**Packages:**
- `test`
- `bench`
- `coverage`
- `debug`
- `quickcheck`

---

Using skill moonbit-agent-guide for MoonBit package review.

**Findings**
- Medium: `count=0` in benchmarks leads to empty `samples` and `percentile` guard failure, since `iter_count` doesn’t enforce a minimum count before calling `winsorize`; see `bench/bench.mbt:26` and `bench/stats.mbt:161`.
- Medium: `PriorityQueue` debug output is documented as “sorted for stable output” but is emitted in heap order without sorting, which can be unstable across runs/targets; see `debug/debug.mbt:200` and `debug/debug.mbt:259`.
- Low: `render` docs mention a `compact_threshold?` parameter and default of 80, but the function has only `max_depth?` and uses `default_threshold = 30`; see `debug/pretty_print.mbt:19` and `debug/pretty_print.mbt:298`.
- Low: `Arbitrary` for `String` builds via repeated concatenation, which is O(n^2) and will be noticeably slow for larger sizes; see `quickcheck/arbitrary.mbt:102`.
- Low/Medium: `size` is not validated as non-negative, but it’s used in modulo operations and as array/bytes lengths, which can break for negative inputs; see `quickcheck/arbitrary.mbt:35` and `quickcheck/arbitrary.mbt:158`.

**Consistency Analysis**
- Style is broadly consistent: block-separated declarations, concise helper functions, and similar method naming (e.g., `Test::new`, `Bench::new`, `RandomState::new`).
- Slight naming/API inconsistency: deprecated aliasing patterns differ (`@test.is_not` alias vs `@debug.inspect` alias), and `Bench::dump_summaries` is public despite being test-only, unlike similar internal helpers that are `#doc(hidden)` elsewhere.

**API Design**
- The surface APIs are small and focused: `@test` helpers, `@bench` batch + single runs, `@debug` representation/rendering, `@coverage` reporting, and `@quickcheck` generators.
- Consider clarifying contracts for “size” parameters in `@quickcheck` and for `count` in `@bench` to avoid edge-case panics (e.g., “must be > 0”), or enforce them internally.

**Implementation Quality**
- `debug`’s `Repr` pipeline is clean and extensible (e.g., `children/with_children` and `traverse` in `debug/repr.mbt`).
- `coverage`’s `end()` logic is robust for line-by-line emission and resets counters to avoid double counting.
- `quickcheck` generators are deterministic and composable, but could be more efficient for string generation (see finding).

**Documentation**
- `debug` has strong narrative docs and examples, but the `render` parameter docs are inaccurate (see finding).
- `bench` and `quickcheck` have relatively minimal docs for public functions; adding a short “parameters/edge cases” block would help.

**Potential Issues**
- See Findings; the most likely user-facing pain points are `count=0` benchmark failures and unstable `PriorityQueue` debug ordering.

**Suggestions**
- Guard `count` in `iter_count` to be at least 1 or raise a clear error; update docs to reflect the constraint (`bench/bench.mbt:26`).
- Either sort priority queue elements before rendering or remove the “stable output” claim and add a note on unstable order (`debug/debug.mbt:200`).
- Fix `render` docs or add the missing `compact_threshold?` parameter to align behavior with documentation (`debug/pretty_print.mbt:298`).
- Switch `String` generation to `StringBuilder` or pre-allocate for O(n) behavior (`quickcheck/arbitrary.mbt:102`).
- Validate `size >= 0` in `Arbitrary::arbitrary` (or in `gen`) and document how negative sizes are handled (`quickcheck/arbitrary.mbt:125`).

If you want, I can propose concrete patches for any of the items above.
