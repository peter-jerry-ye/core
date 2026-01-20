# Review: Immutable Collections Internals

**Packages:**
- `immut/priority_queue`
- `immut/hashset`
- `immut/internal/sparse_array`
- `immut/internal/path`

---

Using moonbit-agent-guide for MoonBit package review and conventions.

**Findings**
- High: `SparseArray::union`/`difference`/`filter` build a FixedArray with `self.data[0]` even when `self` is empty, which can crash on empty inputs (e.g., `@sparse_array.empty().union(@sparse_array.singleton(1, 1), ...)`). See `immut/internal/sparse_array/sparse_array.mbt:116`, `immut/internal/sparse_array/sparse_array.mbt:180`, `immut/internal/sparse_array/sparse_array.mbt:224`.
- Medium: `Bitset::remove` toggles the bit with XOR, so calling `remove` on an absent index will add it (no precondition documented). See `immut/internal/sparse_array/bitset.mbt:56`.
- Medium: Index bounds are implicit for bitset/sparse array paths (`idx` expected 0..31). No guard or doc; out-of-range shifts are undefined/incorrect. See `immut/internal/sparse_array/bitset.mbt:23` and `immut/internal/sparse_array/sparse_array.mbt:65`.
- Low: `priority_queue` README claims a “pairing heap” and recommends `of()`, but implementation is a binary heap and `of()` is deprecated. See `immut/priority_queue/README.mbt.md:3`, `immut/priority_queue/README.mbt.md:9`.
- Low: Path README’s example comment says “Single level path” while `is_last` is `false`; this is misleading. See `immut/internal/path/README.mbt.md:15`.

**1. Consistency Analysis**
- Naming is generally consistent (`new`, `from_array`, `from_iter`, `length`, `is_empty`), but `SparseArray::empty()` is a free fn while others use `new()`; decide whether internal APIs should mirror `new()` for consistency.
- Deprecated aliases are in-line instead of `deprecated.mbt` (files exist but empty). This diverges from the repo refactoring tip; consider consolidating aliases there for uniformity.

**2. API Design**
- Priority queue APIs are intuitive, but `to_array`/`iter` ordering is undocumented (they return descending sorted order). Add a doc note in `immut/priority_queue/priority_queue.mbt:38` and `immut/priority_queue/priority_queue.mbt:56` to clarify ordering and cost.
- HashSet’s `length` is documented as O(n), which is good; but note that `iter` is order-agnostic and not guaranteed stable (implicitly true).

**3. Implementation Quality**
- `PriorityQueue::iter` allocates and sorts the entire queue (`to_array` + sort + reverse) on each iterator creation, making `iter`, `Hash`, and `ToJson` O(n log n) per call. See `immut/priority_queue/priority_queue.mbt:38` and `immut/priority_queue/types.mbt:24`.
- `SparseArray` set operations are clear, but the fixed-array allocation default element bug on empties is a correctness issue (see findings).

**4. Documentation**
- Priority queue README is inconsistent with implementation and includes deprecated `of()` usage. See `immut/priority_queue/README.mbt.md:3` and `immut/priority_queue/README.mbt.md:9`.
- Path README’s “Single level path” comment is misleading. See `immut/internal/path/README.mbt.md:15`.
- Internal packages have adequate README coverage but function-level docstrings are sparse in `immut/internal/sparse_array/sparse_array.mbt`.

**5. Potential Issues**
- Empty sparse array operations can crash due to `self.data[0]` access (High).
- `Bitset::remove` semantics can silently add elements if misused (Medium).
- Index out-of-range for `Bitset`/`SparseArray`/`Path::push` is not guarded or documented (Medium/Low).

**6. Suggestions**
- Fix empty-case allocation by choosing a default from the non-empty operand or by guarding on `elem_info == empty_bitset` before calling `FixedArray::make` in `SparseArray::union`, `difference`, and `filter` (`immut/internal/sparse_array/sparse_array.mbt:116`, `immut/internal/sparse_array/sparse_array.mbt:180`, `immut/internal/sparse_array/sparse_array.mbt:224`).
- Change `Bitset::remove` to clear (`& ~`) or document a strict precondition; add a unit test for “remove absent” to clarify semantics (`immut/internal/sparse_array/bitset.mbt:56`).
- Document valid index range (0..31) for `SparseArray`/`Bitset`/`Path` operations and consider runtime guards in internal helpers if misuse is plausible.
- Update `immut/priority_queue/README.mbt.md` to reflect the binary-heap implementation and use `from_array` instead of `of()`.

If you want, I can draft fixes or add tests for the empty sparse array operations and Bitset remove behavior.
