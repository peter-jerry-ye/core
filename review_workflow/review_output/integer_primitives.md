# Review: Integer Primitives

**Packages:**
- `int`
- `int16`
- `int64`
- `uint`
- `uint64`

---

**Findings**
- Low: Deprecated blocks live in primary files instead of `deprecated.mbt`, which breaks the repo refactoring guideline and makes the public surface harder to scan. Examples: `int/int.mbt:23`, `int/int.mbt:29`, `int64/int64.mbt:21`, `uint/uint.mbt:37`.
- Low: Endian byte conversion APIs are inconsistent: `Int::to_be_bytes`/`to_le_bytes` and `UInt::to_be_bytes`/`to_le_bytes` are deprecated+hidden (`int/int.mbt:29`, `uint/uint.mbt:37`), `Int64::to_be_bytes`/`to_le_bytes` are also deprecated+hidden (`int64/int64.mbt:36`), but `UInt64::to_be_bytes`/`to_le_bytes` are public and documented (`uint64/uint64.mbt:21`). This is a confusing public API split.
- Low: `UInt` has a top-level `default()` in addition to `Default` impl (`uint/uint.mbt:31`), but `Int`, `Int16`, `Int64`, `UInt64` do not. That asymmetry makes the API feel accidental.
- Low: Doc coverage and wording are uneven. `Int16` has rich docstrings for conversions but no docs for core operations/traits (`int16/int16.mbt:21-118`), while `int/int64/uint/uint64` are mostly undocumented beyond minimal comments (`int/int.mbt:15`, `int64/int64.mbt:15`, `uint/uint.mbt:15`, `uint64/uint64.mbt:15`). Also minor doc mismatches: parameter name “value” vs `self` (`int16/int16.mbt:226-255`), and the comment “Sign is preserved” for `Byte`→`Int16` is misleading (Byte is unsigned) (`int16/int16.mbt:176-178`).
- Low: `Int16::abs` silently wraps at `min_value` like `Int::abs`; tests expect this, but the behavior is not documented (`int16/int16.mbt:97`).

**Consistency analysis**
- Naming and block style are consistent (lower_snake for values, `Type::method`, `///|` blocks).
- API surface is inconsistent across sizes: only `Int16` defines arithmetic trait impls and conversion helpers in-package (`int16/int16.mbt:21-270`), while `Int`, `Int64`, `UInt`, `UInt64` mostly expose constants and a few helpers. If that’s intentional because other types are handled in `builtin`, it’s worth documenting or aligning.
- Deprecated API handling is inconsistent: `Int`’s `abs` is deprecated but not hidden (`int/int.mbt:23`), whereas `Int64::abs` is deprecated+hidden (`int64/int64.mbt:29`).

**API design**
- Core constants (`min_value`, `max_value`) are consistently named, but only `Int16` types its constants explicitly (`int16/int16.mbt:15-19`), which is inconsistent but harmless.
- The byte-order APIs are inconsistent across widths (public for `UInt64` but deprecated for others), which complicates discovery and adds surprises for users migrating between types.

**Implementation quality**
- The `Int16` arithmetic impls are clear and efficient; conversions use 32-bit ops, which are safe for 16-bit ranges.
- Shift/bitwise operations rely on `Int` semantics; tests cover common and overflow-like cases.

**Documentation**
- `Int16` conversions are well documented with examples.
- The rest of the group has thin or no documentation for exported items; constants in `int64/uint/uint64` don’t explain their ranges or semantic intent.

**Potential issues / edge cases**
- `Int16::abs` for `min_value` returns `min_value` (wraparound). This is intentional in tests, but not documented. Users may assume absolute value always non-negative.

**Suggestions**
1) Move deprecated functions into per-package `deprecated.mbt` files to follow the local refactoring guideline (e.g., move `int/int.mbt:23-54`, `int64/int64.mbt:21-65`, `uint/uint.mbt:37-60`).  
2) Normalize endian-byte APIs across all integer packages: either keep them all public or all deprecated+hidden, and document the preferred replacement. `uint64/uint64.mbt:21` is the outlier.  
3) Decide whether `default()` should be a top-level helper for all integer packages or only `UInt`; align accordingly to avoid asymmetric APIs (`uint/uint.mbt:31`).  
4) Tighten doc consistency: document the `min_value`/`max_value` constants across `int64/uint/uint64` and clarify `Int16::abs` behavior at `min_value` (`int16/int16.mbt:97`).  
5) Fix doc wording in `Int16::from_byte` (“Sign is preserved”) and align parameter naming (“self” vs “value”) for clarity (`int16/int16.mbt:176-178`, `int16/int16.mbt:226-255`).

**Open questions / assumptions**
- Are arithmetic trait impls for `Int16` meant to be the only integer type with explicit trait impls, or should `Int`, `Int64`, `UInt`, `UInt64` follow a similar pattern for consistency?
- Is the intent to steer users toward `@buffer` for byte order conversions across all integer types, and should that be documented in these packages?

If you want, I can draft a concrete alignment proposal (deprecated split + API normalization) and make the edits.
