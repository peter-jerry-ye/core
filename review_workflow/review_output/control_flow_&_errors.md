# Review: Control Flow & Errors

**Packages:**
- `option`
- `result`
- `error`
- `abort`
- `unit`

---

Here are the review findings first (ordered by severity), then the requested sections.

**Findings**
- Doc/behavior mismatch in `abort` on non‑native targets: the docs say the message is displayed, but the non‑native implementation discards it (`abort/abort.mbt:16-30`). This can surprise users who rely on the message for diagnostics.
- The Option package has two empty source files (`option/option.mbt`, `option/methods.mbt`), while only `option/deprecated.mbt` defines APIs. This is consistent with “deprecated-only” intent but is confusing without a short package/module doc that explains where the main API lives (e.g., prelude/builtin).
- The public `Error` trait impls don’t help suberrors automatically; tests call this out as a UX gap (see commentary in `error/error_test.mbt`, e.g., the TODO around `ToJson`/`Show`). This isn’t a bug, but it is an API ergonomics issue worth documenting or addressing.

**Consistency Analysis**
- Style and structure are mostly consistent: block separators, copyright headers, and deprecation placement are aligned across packages (`option/deprecated.mbt`, `result/deprecated.mbt`, `unit/unit.mbt`).
- Documentation is inconsistent: `abort/abort.mbt` and `error/error.mbt` have full docstrings, but deprecated APIs in `option/deprecated.mbt` and `result/deprecated.mbt` have only `#deprecated` messages.
- The presence of empty files in `option` is inconsistent with other packages that either define content or are clearly deprecated-only.

**API Design**
- The deprecated wrappers in `option/deprecated.mbt` and `result/deprecated.mbt` point users to idiomatic replacements, which is good. However, without any non‑deprecated API in this package directory, it’s not obvious where the “real” Option/Result APIs live.
- `abort` has a clean, generic signature `pub fn[T] abort(msg : String) -> T` that matches panic‑style APIs, but the “message displayed” promise is only true for native (`abort/abort.mbt:16-50`).
- `Error` exposes `Show`/`ToJson` impls that feel right for the core error type, but this design doesn’t automatically improve suberror inspection, which is unexpected for many users (see `error/error_test.mbt`).

**Implementation Quality**
- Implementations are simple and correct; nothing looks inefficient or overly complex.
- The only correctness concern is the doc/behavior mismatch in `abort` on non‑native targets (`abort/abort.mbt:16-30`).

**Documentation**
- Strong: `error/error.mbt` has a thorough docstring and example for `Show` (`error/error.mbt:19-41`).
- Weak: deprecated APIs have no docstrings; users only see deprecation messages (`option/deprecated.mbt:15-44`, `result/deprecated.mbt:15-49`).
- Weak: the lack of any package‑level doc explaining where Option/Result functionality is implemented (since `option/option.mbt` is empty).

**Potential Issues**
- Misleading `abort` docs on non‑native targets (`abort/abort.mbt:16-30`).
- UX gap: suberrors don’t inherit `Show`/`ToJson` behavior implicitly; tests note this and hint at confusion (`error/error_test.mbt`, TODO comment).

**Suggestions**
- Align `abort` docs with behavior or implement logging on non‑native targets:
  - Either change docs to “message may be ignored on non‑native targets,” or add a non‑native print mechanism if available (`abort/abort.mbt:16-30`).
- Add a short module/package doc in `option/option.mbt` (or `option/methods.mbt`) explaining that the primary Option API is in the core/prelude, and this package only holds deprecated shims.
- Add brief docstrings to deprecated wrappers describing behavior before the deprecation notice, so IDE docs are more usable (`option/deprecated.mbt:15-44`, `result/deprecated.mbt:15-49`).
- Document the current limitation of suberror `Show`/`ToJson` behavior (or consider auto‑derive for suberror types if that’s a roadmap item), to set expectations for `@json.inspect`/`inspect` with custom errors (see `error/error_test.mbt`).

If you want, I can also scan the generated `.mbti` files to confirm the public API surfaces for these packages.
