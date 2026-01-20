# Review: Immutable Collections Core

**Packages:**
- `immut/array`
- `immut/list`
- `immut/hashmap`
- `immut/sorted_map`
- `immut/sorted_set`

---

Using moonbit-agent-guide because this is a MoonBit stdlib package review.

**Findings**
- Medium: Deprecated API blocks live in `../immut/list/list.mbt` rather than being isolated in `deprecated.mbt`, unlike the other packages (`../immut/list/list.mbt`).
- Medium: `HashMap::length` is O(n) and `HashMap::to_array` calls it for capacity, so `to_array` does two full traversals (`../immut/hashmap/HAMT.mbt:339`, `../immut/hashmap/HAMT.mbt:726`).
- Low: `HashMap::at`/`SortedMap::at` panic on missing keys but this is not documented and uses `unwrap()`/`panic()` without a clear message (`../immut/hashmap/HAMT.mbt:64`, `../immut/sorted_map/utils.mbt:102`).
- Low: Doc mismatches/typos: `Tree::get_first`/`get_last` comments are swapped (`../immut/array/tree.mbt:63`), the compare example comment is wrong (`../immut/array/array.mbt:423`), and `rev_iter` example lacks `mbt check` (`../immut/sorted_set/generic.mbt:22`).
- Low: Tests live in a non-test file in sorted_set while other packages keep tests in `*_test.mbt` (`../immut/sorted_set/generic.mbt:121`).

**Consistency Analysis**
- Naming and block style are mostly consistent: `new`, `singleton`, `from_array`, `from_iter`, `get`/`at`, and `each` appear across packages with similar semantics.
- Inconsistencies: deprecated items concentrated in `../immut/list/list.mbt` instead of `../immut/list/deprecated.mbt`, and `sorted_set` embeds tests in `../immut/sorted_set/generic.mbt` while others separate test files.
- Naming across map/set APIs is close but not aligned: `SortedMap::merge` vs `HashMap::union` vs `SortedSet::merge` suggest similar operations but different names (`../immut/sorted_map/map.mbt:159`, `../immut/hashmap/HAMT.mbt:362`, `../immut/sorted_set/immutable_set.mbt:913`).

**API Design**
- The `get` vs `at` split is good and consistent: `get` returns `Option`, `at` panics (array/list/map/set variants).
- HashMap has an ergonomic `keys()`/`values()` iterator API similar to sorted_map/sorted_set, but length is much more expensive than in sorted_map/set.
- Potential confusion from `merge` vs `union` naming across the map types; a simple alias would make the API feel more uniform.

**Implementation Quality**
- Overall implementations look solid: array uses a balanced tree with size tracking, sorted_map/set use balanced BSTs, hashmap uses HAMT.
- `HashMap::to_array` performs two traversals due to `length()` being O(n); this is a performance footgun for large maps (`../immut/hashmap/HAMT.mbt:339`, `../immut/hashmap/HAMT.mbt:726`).
- Array tree utilities are well-factored; minor TODOs are noted (e.g., tree set loop).

**Documentation**
- Array and sorted_map have richer docs and examples; hashmap and sorted_set are sparser and occasionally inconsistent.
- Concrete doc issues: swapped left/right comment in tree getters, and the incorrect compare example comment (`../immut/array/tree.mbt:63`, `../immut/array/array.mbt:423`).
- Example in `SortedSet::rev_iter` isn’t marked as `mbt check`, so it won’t be tested (`../immut/sorted_set/generic.mbt:22`).

**Potential Issues**
- Panic behavior for `HashMap::at`/`SortedMap::at` is implicit; users may assume it’s safe like `get`. Consider documenting explicitly or adding `*_exn` naming (`../immut/hashmap/HAMT.mbt:64`, `../immut/sorted_map/utils.mbt:102`).
- `HashMap::to_array` double-walks for capacity; could be unexpectedly slow on large maps (`../immut/hashmap/HAMT.mbt:339`, `../immut/hashmap/HAMT.mbt:726`).

**Suggestions**
1) Move deprecated list APIs into `../immut/list/deprecated.mbt` for consistency with other packages and the refactoring guidance.
2) Add alias names so `HashMap::union` and `SortedMap::merge`/`SortedSet::merge` feel aligned (or document the naming rationale) (`../immut/hashmap/HAMT.mbt:362`, `../immut/sorted_map/map.mbt:159`).
3) Fix doc inaccuracies and add `mbt check` where intended: tree getter comments, compare example comment, and `rev_iter` example (`../immut/array/tree.mbt:63`, `../immut/array/array.mbt:423`, `../immut/sorted_set/generic.mbt:22`).
4) Consider tracking size in `HashMap` (or provide a cheap `to_array` without prealloc) to avoid double traversal, and document `length()` cost prominently (`../immut/hashmap/HAMT.mbt:339`, `../immut/hashmap/HAMT.mbt:726`).
5) Document panic behavior for all `*_::at` functions consistently (array/map/set/hashmap) so users know when to prefer `get`.
