# Review: Runtime Data & Serialization

**Packages:**
- `strconv`
- `json`
- `bytes`
- `buffer`
- `env`

---

**Potential Issues**
- JSON numeric overflow is treated as Infinity with a preserved string repr, which makes `parse` accept syntactically valid but non-finite numbers and later `FromJson` rejects them as “expected number.” See `json/lex_number.mbt:152-178` (Infinity fallback), `json/json.mbt:297-310` (stringify uses repr), and `json/from_json.mbt:50-110` (Infinity rejected). This can break round-trips like `parse -> from_json` for large integers or exponents.
- JSON string escape handling does not combine surrogate pairs from `\uXXXX\uYYYY`, and it will happily emit isolated surrogate code units. See `json/lex_string.mbt:43-46`. That is non-compliant for JSON strings representing non-BMP code points.
- `env.now()` precision is backend-dependent: native uses `time(0)` (seconds) and multiplies by 1000 (`env/env_native.mbt:78-81`) while JS uses `Date.now()` (millisecond precision, `env/env_js.mbt:26-30`). That makes `now()` resolution inconsistent across targets.
- `env.current_dir()` in native uses a fixed 4096-byte buffer and returns `None` on failure without retry, which can fail for long paths (`env/env_native.mbt:89-96`).

**Consistency Analysis**
- Parsing APIs in `strconv` are consistent in naming (`parse_int`, `parse_uint`, `parse_double`, `parse_bool`) and use `StringView` plus `raise StrConvError` across the board (`strconv/int.mbt`, `strconv/uint.mbt`, `strconv/double.mbt`, `strconv/bool.mbt`).
- JSON uses `parse`/`stringify` and a dedicated error type (`ParseError`), while decoding uses `FromJson` + `JsonDecodeError` (clear separation).
- Deprecated APIs are not consistently placed in `deprecated.mbt` as suggested by AGENTS guidance; for example, deprecations live in `json/json.mbt` and `bytes/alias.mbt`, while `buffer/deprecated.mbt` is empty.
- Backend-specific env implementations are structurally consistent (internal functions in `env_*`), but behavior is not (timestamp precision, path handling).

**API Design**
- `FromJson` for `Int64`/`UInt64` requires a string representation (`json/from_json.mbt:65-100`), while `Int`/`UInt` accept numeric JSON (`json/from_json.mbt:50-88`). That’s a reasonable precision choice, but it is an API surprise and differs from `Int/UInt`; it should be documented prominently in the JSON module docs.
- The `Json::stringify` `replacer` is a nice, JS-like design, but it only applies to object properties, not array elements, which should be explicitly called out (it is in comments, but not in a top-level doc).
- `env.args()` returns `process.argv` for JS (`env/env_js.mbt:16-23`), which includes node runtime + script path; on native, it depends on FFI. If this is intentional, it may be worth stating to avoid cross-platform surprises.

**Implementation Quality**
- `strconv` parsing is careful about overflow (threshold checks in `parse_int64`/`parse_uint64`) and uses fast/slow paths for double parsing; overall high-quality.
- The `checked_mul` helper for float parsing explicitly admits false negatives and “not completely safe against overflows” (`strconv/number.mbt:181-184`). Since it feeds into fast-path parsing (`strconv/double.mbt`), this could lead to subtle correctness issues in edge cases. Consider tightening this or ensuring the slow path is used for all ambiguous cases.
- JSON parsing uses an explicit stack in `Json::stringify` to avoid recursion (nice), and a depth limit in `parse` to avoid stack overflows (`json/parse.mbt:73-117`).

**Documentation**
- `buffer/buffer.mbt` is well-documented with examples; `strconv` parsing functions have detailed docs and examples.
- `bytes/regex.mbt` and `bytes/regex_pattern.mbt` are internal/experimental but effectively undocumented aside from the `#internal` tags; if they’re meant for internal use only, consider hiding from docs entirely or adding short “internal use only” notes.
- `env` module docs are brief and should mention platform-specific behaviors (timestamp precision, CLI arg shape, current_dir failure modes).

**Suggestions**
1. Clarify numeric overflow semantics in JSON: either return a `ParseError` for numbers that cannot be represented as finite `Double`, or formalize the `Infinity + repr` approach in docs and provide a safe accessor for the string repr so users don’t accidentally treat Infinity as real data (`json/lex_number.mbt:152-178`, `json/json.mbt:297-310`).
2. Add surrogate-pair handling and validation for `\uXXXX` escapes in JSON strings, rejecting isolated surrogates (`json/lex_string.mbt:43-46`).
3. Document the `FromJson` expectations for `Int64`/`UInt64` vs `Int`/`UInt` and consider offering alternative impls (e.g., accept `Number` when within safe range) to reduce surprises (`json/from_json.mbt:50-100`).
4. Make `env.now()` resolution consistent across backends or document the discrepancy, and consider a higher-resolution native time source if available (`env/env_native.mbt:78-81`, `env/env_js.mbt:26-30`).
5. For `env.current_dir()` on native, consider retrying with a larger buffer on `getcwd` failure, or document the 4096-byte limit (`env/env_native.mbt:89-96`).
6. Consolidate deprecations into `deprecated.mbt` per the refactoring guidance to keep public-facing files focused (e.g., `json/json.mbt`, `bytes/alias.mbt`).

If you want, I can deep-dive any one package with a targeted change proposal or draft updated docs for the JSON numeric and `FromJson` behaviors.
