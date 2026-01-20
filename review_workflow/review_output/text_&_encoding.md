# Review: Text & Encoding

**Packages:**
- `string`
- `char`
- `encoding/utf8`
- `encoding/utf16`
- `internal/regex_engine/shared_types/rechar_set`

---

**Findings**
- High: `decode_lossy` stops at the first malformed chunk because the `_ => builder.write_char(U_REP)` branches do not `continue`, so the loop exits and truncates remaining bytes; this affects both endianness paths in `encoding/utf16/decode.mbt:149` and `encoding/utf16/decode.mbt:177`.
- Medium: `decode_lossy` for UTF-8 replaces invalid multi‑byte sequences but only consumes 2–3 bytes for those cases (e.g. 3‑byte and 4‑byte invalid branches at `encoding/utf8/decode.mbt:222`–`encoding/utf8/decode.mbt:247`), which can desynchronize decoding and emit extra U+FFFDs compared to standard “consume one byte” or “consume full expected length” behaviors.
- Low: `RecharSet::offset_by` accepts any mapping and assumes ordering is preserved; a non‑monotonic `f` can invert or overlap intervals without guardrails (`internal/regex_engine/shared_types/rechar_set/rechar_set.mbt:266`), which is fine for internal use but fragile as a public method.

**Consistency Analysis**
- Naming is generally consistent across encoding packages (`encode`/`decode`/`decode_lossy`, `Malformed` error type), and both UTF‑8 and UTF‑16 accept `StringView`/`BytesView` inputs (`encoding/utf8/encode.mbt`, `encoding/utf8/decode.mbt`, `encoding/utf16/encode.mbt`, `encoding/utf16/decode.mbt`).
- There’s a minor naming mismatch: UTF‑8/UTF‑16 `encode` uses `bom?`, while `decode` uses `ignore_bom?`. It reads a little asymmetric for callers when `encode` is “include BOM” and `decode` is “ignore BOM”.
- The `string` and `char` packages are mostly wrappers or empty shells: `string/string.mbt` contains deprecated forwarders, `string/view.mbt` just re‑exports `ToStringView`, and `char/char_util.mbt` is empty. That pattern isn’t mirrored in `encoding/*`, so the “package as a shim” approach is inconsistent across this group.

**API Design**
- The UTF encoders/decoders are intuitive: `encode` returns `Bytes`, `decode` returns `String`, and `decode_lossy` avoids errors. This is consistent between UTF‑8 and UTF‑16.
- `encoding/utf16` exposes `Endian` but UTF‑8 doesn’t need it, which is fine. The type is `pub(all)` and used in signatures, so it is discoverable.
- `string/regex.mbt` uses `#internal(experimental)` for `Regex`/`MatchResult` APIs, which is honest about stability. However, these are still `pub` and lack docs; if the intent is to keep them out of public API, consider making them `#doc(hidden)` too (like `string/regex_pattern.mbt`).

**Implementation Quality**
- UTF‑8 decode logic is efficient: fast ASCII unroll, explicit validation, and direct UTF‑16LE output. This is clear and performant (`encoding/utf8/decode.mbt`).
- UTF‑16 decode validates surrogate pairs in both endianness paths, with the correct range checks (`encoding/utf16/decode.mbt:42`–`99`).
- Regex UTF‑16 lowering is well‑structured: it cleanly maps high code points to surrogate pair sequences and wraps alternations with `@re.shortest` (`string/regex_utf16.mbt`).
- The `RecharSet` tree structure is a solid interval‑set implementation with balance logic and union/intersection/difference; the code is dense but consistent (`internal/regex_engine/shared_types/rechar_set/tree.mbt`, `internal/regex_engine/shared_types/rechar_set/rechar_set.mbt`).

**Documentation**
- Many public functions lack docs or examples: `encoding/utf8/decode` and `encoding/utf8/decode_lossy` are essentially undocumented (`encoding/utf8/decode.mbt`), and `encoding/utf16/decode` only has a minimal reference note (`encoding/utf16/decode.mbt`).
- `RecharSet` public API has no docstrings at all, even though it’s non‑trivial to use correctly (`internal/regex_engine/shared_types/rechar_set/rechar_set.mbt`).
- In `string`/`char`, the package surface is mostly re‑exports or deprecated helpers, but that isn’t called out anywhere besides per‑function deprecations (`string/string.mbt`). A small package‑level README pointer would help.

**Potential Issues**
- Lossy UTF‑16 decode truncation after first malformed segment (see findings).
- Lossy UTF‑8 decode may produce different replacement behavior than users expect due to partial sequence consumption (see findings).
- `RecharSet::offset_by` can silently produce invalid sets for non‑monotone transforms, which could bite future internal uses.

**Suggestions**
- Fix UTF‑16 lossy decode to `continue rest` in the `_` branches so it keeps decoding after malformed bytes; add a test case with trailing junk to confirm behavior (`encoding/utf16/decode.mbt`).
- Consider aligning BOM options by renaming `ignore_bom?` to something symmetric like `skip_bom?` (or add a doc note in both `encode`/`decode` so users understand the mismatch).
- Tighten or document UTF‑8 lossy replacement behavior; decide whether you want to consume a single byte or the full expected sequence length on malformed input and encode that policy explicitly (`encoding/utf8/decode.mbt`).
- Add short docstrings for `encoding/utf8`/`encoding/utf16` public functions and a brief note for `RecharSet` on interval ordering and the expected monotonicity of `offset_by`.

If you want, I can propose concrete fixes and tests for the UTF‑16 lossy decode and the UTF‑8 replacement behavior.

Next steps if you want verification:
1. Run `moon test encoding/utf16 encoding/utf8`.
2. Run `moon fmt` after changes.
