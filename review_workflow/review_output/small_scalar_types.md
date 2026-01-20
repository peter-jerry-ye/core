# Review: Small Scalar Types

**Packages:**
- `uint16`
- `byte`
- `bool`

---

Using skill: moonbit-agent-guide (MoonBit package layout + review conventions).

Here’s a focused review of the three packages based on their `.mbt` sources (plus `.mbti`/README for API/doc accuracy).

**Consistency Analysis**
- `byte` and `uint16` both expose `max_value`/`min_value` as `pub let` constants, with identical naming and block style (`///|`) in `../byte/byte.mbt` and `../uint16/uint16.mbt`.
- `bool` has no `.mbt` implementation at all (only tests), so it breaks the pattern of “package defines minimal helpers/constants.”
- Deprecated API placement is inconsistent with the repo guideline “keep deprecated blocks in `deprecated.mbt`”: `../uint16/uint16.mbt:22-25` embeds a deprecated function inline.
- Test style varies: `Hasher::new` is used unqualified in `../bool/bool_test.mbt:15-19` and `../uint16/uint16_test.mbt:176-179`, but `@builtin.Hasher::new` is used in `../uint16/uint16_test.mbt:329-333`. This is minor but inconsistent.

**API Design**
- `byte` and `uint16` APIs are extremely minimal (only min/max constants; plus one deprecated method in `uint16`). This is consistent with “tiny scalar type helpers.”
- `bool` exports nothing (`../bool/pkg.generated.mbti` is empty). That’s inconsistent with the group’s “helpers” scope and with its README’s claims.
- `uint16` exposes a deprecated method `UInt16::reinterpret_as_int16` (good to deprecate), but the implementation doesn’t call the recommended replacement directly.

**Implementation Quality**
- Constants are straightforward and correct: `../byte/byte.mbt:16-19`, `../uint16/uint16.mbt:16-19`.
- Potential semantic mismatch in `UInt16::reinterpret_as_int16`:  
  `../uint16/uint16.mbt:22-25` uses `Int16::from_int(self.to_int())`. If `Int16::from_int` ever changes to clamp or otherwise behave differently, this would not guarantee bit reinterpretation. Since the deprecation message points to `Int16::reinterpret_from_uint16`, this should likely call that directly for correctness + clarity.

**Documentation**
- README coverage is good and includes `mbt check` tests, but source-level docstrings are missing for the exported constants:
  - `../byte/byte.mbt:16-19`  
  - `../uint16/uint16.mbt:16-19`  
  This means `moon doc` users won’t see descriptions at the API entry points.
- README accuracy issues:
  - `../byte/README.mbt.md` claims “package function (`@byte.to_uint64(b)`),” but the package exports no such function (`../byte/pkg.generated.mbti` only lists `min_value`/`max_value`). This is misleading.
  - `../bool/README.mbt.md` repeatedly says “this package provides utility functions,” but `../bool/pkg.generated.mbti` shows it exports nothing. The README is effectively documenting core `Bool` methods, not this package.

**Potential Issues**
- Misleading or incorrect README API claims:
  - `../byte/README.mbt.md` references `@byte.to_uint64`, which doesn’t exist in the package.
  - `../bool/README.mbt.md` suggests package-provided utilities, but the package is empty.
- Deprecated function placement violates repo guidance:
  - `../uint16/uint16.mbt:22-25` should live in `deprecated.mbt`.
- Test mislabeled for Int64 conversions:
  - `../uint16/uint16_test.mbt:58-74` is titled “UInt16::from_int64” but only calls `Int::to_uint16`, so it never tests `Int64` conversion behavior.

**Suggestions**
1) Align README claims with actual exports.  
   - Update `../byte/README.mbt.md` to remove `@byte.to_uint64` or add a wrapper function in `byte.mbt` if that’s desired.  
   - Update `../bool/README.mbt.md` to clarify it documents built-in `Bool` conversions (or add actual helpers to the package).

2) Move deprecated API into a dedicated file and call the replacement directly.  
   - Move `UInt16::reinterpret_as_int16` from `../uint16/uint16.mbt` to `../uint16/deprecated.mbt`.  
   - Implement it as `Int16::reinterpret_from_uint16(self)` to guarantee correct semantics and align with the deprecation message.

3) Fix the Int64 test coverage.  
   - In `../uint16/uint16_test.mbt:58-74`, replace `Int::to_uint16(...)` with `Int64::to_uint16(...)` and include `Int64`-typed literals to validate `UInt16::from_int64` properly.

4) Add brief docstrings for exported constants.  
   - For `../byte/byte.mbt` and `../uint16/uint16.mbt`, a short docstring like “Minimum value of Byte/UInt16” improves `moon doc` output.

If you want, I can draft the README fixes and the deprecated method move. Suggested next steps:
1) I update the README(s) and adjust the `uint16` deprecated function placement/implementation.
2) I fix the Int64 test and run `moon info && moon fmt` to validate the interface and formatting.
