# Review: Core Language Utilities

**Packages:**
- `builtin`
- `prelude`
- `cmp`
- `tuple`
- `ref`

---

**Findings**
- Medium: `../cmp/cmp.mbt:36-39` `Reverse::compare` negates the result of `compare`, which can overflow if a `Compare` impl returns `Int::min` (or any non-{-1,0,1} value). Safer reversal is `b.0.compare(a.0)` to avoid negation overflow.
- Medium: `../builtin/option.mbt:25-29` `Option::to_string` builds `Some(` + `x.to_string()` + `)`, which yields raw strings for `String` (since `String::to_string` is unescaped) while the `Show` impl for `X?` escapes via `write_object` (`../builtin/show.mbt:181-187`). This makes `option.to_string()` inconsistent with `repr()` / `Show`, especially for strings containing newlines or quotes.
- Low: `../builtin/traits.mbt:65-75` `Hash` docs say `hash` does not need to be consistent with `hash_combine`, which conflicts with the trait’s own guidance (“equal values should produce the same hash”) and with the default `hash` implementation (`../builtin/traits.mbt:81-83`) that uses `hash_combine`. This reads as a documentation bug and can mislead implementers.
- Low: Several public APIs lack descriptive docs or examples (e.g. `../ref/ref.mbt:121-123` `Ref::update`, `../builtin/show.mbt:44-58` `Byte::to_hex`, `../builtin/option.mbt:25-29` `Option::to_string`). Most other public APIs have examples, so these stand out.

**Consistency Analysis**
- Naming conventions and block structure are consistent (`///|` blocks, lower_snake for functions, UpperCamel for types).
- Deprecated items are properly isolated in `deprecated.mbt` for `tuple` and `builtin`.
- Inconsistency: tests live inline in `../ref/ref.mbt` while other packages favor `_test.mbt` files (e.g. `builtin`). This is stylistic but worth aligning.
- Inconsistency: `Option` exposes a bespoke `Option::to_string`, while `Result` relies on `Show`. That makes the user mental model for “stringify” uneven across core types.

**API Design**
- `@prelude` re-exports are clean and focused; APIs like `tap` are intuitive and documented well (`../prelude/prelude.mbt`).
- `@cmp` helpers are small and predictable; return-tie behavior is documented clearly.
- Consider aligning the `Option` convenience methods with `Result` naming/availability (e.g., alias deprecations in `Option` but not in `Result`).

**Implementation Quality**
- Core implementations are clear and efficient (`Array::make`, `Array::makei`, `Result::map`, `Ref::protect`).
- The one correctness risk I saw is `Reverse::compare` negation overflow as noted above.

**Documentation**
- Array/bytes/string APIs are richly documented with examples.
- Some public helpers are missing doc text or examples; adding short docs to `Ref::update`, `Option::to_string`, and `Byte::to_hex` would improve parity.

**Potential Issues**
- `Reverse::compare` overflow risk (`../cmp/cmp.mbt:36-39`).
- `Option::to_string` produces output inconsistent with `Show` for `Option` (`../builtin/option.mbt:25-29` vs `../builtin/show.mbt:181-187`).

**Suggestions**
- Prefer `b.0.compare(a.0)` over negating `compare` in `Reverse` to avoid overflow.
- Either deprecate `Option::to_string` in favor of `Show`/`repr`, or reimplement it using `Show::output` to match the escaped representation.
- Clarify the `Hash` docs to state that `hash` and `hash_combine` should be consistent when both are implemented.
- Move the inline tests in `../ref/ref.mbt` into `../ref/ref_test.mbt` for consistency with other packages.

**Open questions / assumptions**
- Is `Option::to_string` intentionally meant to be “display-like” (unescaped) rather than `Show`-like? If so, it may deserve a dedicated name (e.g. `to_display_string`) or documentation warning.

If you want, I can propose targeted doc/behavior fixes for the findings above.
