# Review: Floating Point & Big Math

**Packages:**
- `float`
- `double`
- `double/internal/ryu`
- `math`
- `bigint`

---

Using skill: moonbit-agent-guide (MoonBit package conventions and review focus).

**Findings**
- High: `BigInt::from_int64` overflows on `Int64::min` because it negates `n` before converting, which is undefined for the minimum two’s‑complement value; this can construct the wrong magnitude. See `bigint/bigint_nonjs.mbt:146`. Example: `from_int64(-9223372036854775808L)` negates `n` before `reinterpret_as_uint64()`.
- High: `BigInt::to_uint` is incorrect for negative values less than `-2^32` because it only adds `2^32` once, not modulo `2^32`. This breaks “lower 32 bits” semantics. See `bigint/bigint_nonjs.mbt:1722`. Example: `(-8589934593N).to_uint()` should be `4294967295`, but `(1N << 32) + self` yields `-(2^32+1)` and `limbs[0]` becomes `1`.
- Medium: `@json.FromJson` for `BigInt` calls `BigInt::from_string` without catching parse failures, so invalid input aborts instead of raising `JsonDecodeError`. See `bigint/bigint.mbt:49`. This is user-visible error handling for JSON decode paths.
- Low: `is_close` docs say “returns false if either number is infinite,” but the implementation returns `true` for `+∞` vs `+∞` due to the `self == other` check (and examples show that behavior). See `float/methods.mbt:225` and `double/double.mbt:225`. The doc should match the behavior (or the behavior should match the doc).
- Low/perf: `two_over_pi` is allocated on each call to `trig_reduce`; it could be a top‑level constant to avoid per‑call allocation. See `math/trig.mbt:58`.

**Consistency Analysis**
- Naming and surface patterns are largely consistent: `@math.powf/expf/sinf` for Float vs `@math.pow/exp/...` for Double align with stdlib conventions.
- Deprecated API placement is inconsistent with the repo guidance: `double/` and `math/` have `deprecated.mbt`, but `float/` has deprecated functions in `float/pow.mbt` and `float/float.mbt` rather than a `float/deprecated.mbt`.
- Deprecation status diverges between Float and Double in similar APIs: `Float::is_close` is active while `Double::is_close` is deprecated (`double/double.mbt:240`), and `Float::to_be_bytes` is public while `Double::to_be_bytes` is deprecated/hidden (`double/double.mbt:275`). This makes the float/double surface feel uneven.

**API Design**
- The push toward `@math.*` functions is clear and consistent, but Float’s `to_string` effectively delegates to Double formatting (`float/methods.mbt:14`), which may surprise users expecting float-precision formatting.
- `BigInt::from_string` aborts on invalid strings in both JS and non‑JS variants, and `FromJson` doesn’t expose a Result-based or error-returning parse path. That’s fine for internal use, but brittle for user input (see `bigint/bigint.mbt:49`).
- The BigInt conversion APIs are convenience-oriented, but as implemented they are not true “low bits modulo” for negative values, which undermines caller expectations.

**Implementation Quality**
- The math implementations appear faithful to the original sources and are well-structured, with careful special-case handling (`math/pow.mbt`, `math/exp.mbt`, `math/log.mbt`, `math/trig.mbt`).
- `BigInt` uses clear invariants and sign/magnitude representation (`bigint/bigint_nonjs.mbt:19`), but the conversion helpers need tighter edge-case handling for negative values.

**Documentation**
- Float, math, and BigInt public APIs are well‑documented with examples.
- `double/limits.mbt` (constants) lacks docstrings while `float/float.mbt` has detailed docs; the same applies to `double/scalbn.mbt` (no public doc). This creates uneven discoverability between Float and Double.
- The `is_close` docs are inconsistent with behavior and examples (see Findings).

**Potential Issues**
- Incorrect conversion semantics for `BigInt::to_uint` / `to_int` for negative values beyond `-2^32` (see Findings).
- `BigInt::from_int64` overflow for `Int64::min` (see Findings).
- JSON decode for BigInt can abort instead of raising a structured error (see Findings).

**Suggestions**
1) Fix `BigInt::from_int64` to handle `Int64::min` explicitly (e.g., special-case `n == Int64::min` and construct via magnitude + sign).  
2) Implement `BigInt::to_uint` as `self mod 2^32` for all signs; expose a helper like `mod_pow2` to keep `to_int`/`to_uint` consistent.  
3) Update `@json.FromJson` for `BigInt` to catch parse errors (or introduce `BigInt::try_from_string`) and raise `JsonDecodeError`.  
4) Align `is_close` documentation with actual behavior (or adjust behavior if the doc is intended).  
5) Consolidate deprecated Float APIs into `float/deprecated.mbt` and align deprecation status of similar Float/Double APIs.  
6) Move `two_over_pi` to a top-level constant in `math/trig.mbt` to avoid per-call allocation.

If you want, I can propose concrete patches for the BigInt conversion fixes and the JSON decode error handling.
