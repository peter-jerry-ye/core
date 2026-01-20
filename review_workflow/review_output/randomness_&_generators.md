# Review: Randomness & Generators

**Packages:**
- `random`
- `random/internal/random_source`
- `quickcheck/splitmix`

---

Using skill moonbit-agent-guide because this is a MoonBit standard library review.

**Findings**
- **Type mismatch in deprecated API**: `random/deprecated.mbt:17`–`random/deprecated.mbt:21` returns `@random_source.ChaCha8::new(seed) as &Source` from a function declared `-> Rand`. If this compiles, it relies on implicit conversion that is not obvious; if it doesn’t, it’s a hard error. Suggest returning `Rand::chacha8(seed~)` or `Rand(@random_source.ChaCha8::new(seed) as &Source)` explicitly.
- **Negative limit handling leaks into huge unsigned ranges**: `random/random.mbt:78`–`random/random.mbt:103` reinterpret negative `limit` to `UInt/UInt64`, so `Rand::int(limit=-1)` or `Rand::int64(limit=-1)` will produce values in an enormous range rather than reject the input. This contradicts “upper bound (exclusive)” semantics and invites silent misuse.
- **`Rand::bigint` accepts invalid bit counts**: `random/random.mbt:214`–`random/random.mbt:223` doesn’t guard `bits <= 0`. For negative values, `len` can become negative (or zero), and `Bytes::makei` is likely to panic or return an empty value, contradicting “random positive BigInt with a specified number of bits.”
- **Doc/behavior mismatch**: `quickcheck/splitmix/random.mbt:69`–`quickcheck/splitmix/random.mbt:72` says “two random number as 32-bit signed integers,” but returns `(UInt, UInt)`.

**Open questions / assumptions**
- Is the negative `limit` behavior intentionally “reinterpret as unsigned” (for legacy compatibility), or should it be guarded like `Rand::shuffle` does?
- Is `Rand` intended to be the common RNG façade for `splitmix` as well? If so, should `RandomState` implement `@random.Source` for consistency?

**Consistency analysis**
- Naming is mostly consistent inside each package (e.g., `Rand::uint64`, `RandomState::next_uint64`), but not across packages: `Rand::int/uint` vs `RandomState::next_int/next_uint`, and a lack of a shared interface in `splitmix`. If the packages are meant to be peer RNG sources, consider a shared naming pattern or an adapter trait.
- Documentation style is mixed: `random/random.mbt` uses `[int]`, `[uint64]` tags, while `quickcheck/splitmix/random.mbt` uses plain sentences. Consider standardizing doc headings or removing bracket tags.

**API design**
- `Rand::new(generator? : &Source)` is a clean extension point, but `splitmix` doesn’t implement `Source`, so its RNG can’t be injected without wrappers. If these are in a “randomness” group, consider adding `impl @random.Source for @splitmix.RandomState` to unify usage.
- `Rand::chacha8` default seed is fixed (`"ABCDEFGHIJKLMNOPQRSTUVWXYZ123456"`). That’s great for reproducibility but should be called out more prominently (API docs or module docs) to prevent users assuming entropy.

**Implementation quality**
- `Rand::uint64` rejection-sampling is solid and avoids modulo bias for non-power-of-two limits (`random/random.mbt:138`–`random/random.mbt:153`).
- `random/internal/random_source/random_source_chacha.mbt` uses a 4-way parallel ChaCha setup; the approach is non-obvious but tests provide strong regression coverage. Consider a brief comment explaining the 4-way layout to aid maintainability.

**Documentation**
- `random/random.mbt` has decent docstrings for numeric generators and `shuffle`, but `bigint` should document bit-count constraints and whether it can return zero.
- `quickcheck/splitmix/random.mbt` lacks any overview of `RandomState` or `gamma`/SplitMix64 properties (period, intended use). A short module doc would help.
- `random/internal/random_source/random_source_chacha.mbt` could benefit from a note that ChaCha8 is not a CSPRNG (if that’s the intent).

**Suggestions**
1. Fix deprecated `new` to return `Rand` explicitly (`random/deprecated.mbt:17`).
2. Add guardrails for negative `limit` in `Rand::int`/`Rand::int64` (abort or return 0) and for `bits <= 0` in `Rand::bigint` (`random/random.mbt:78`, `random/random.mbt:94`, `random/random.mbt:214`).
3. Align docstrings for `RandomState::next_two_uint` with the actual unsigned return type (`quickcheck/splitmix/random.mbt:69`).
4. Consider exposing `RandomState` as a `@random.Source` implementation to make the RNGs interoperable.

If you want, I can follow up with concrete patches for the issues above.
