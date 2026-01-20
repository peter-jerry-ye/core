# Review: Mutable Map/Set Collections

**Packages:**
- `hashmap`
- `hashset`
- `set`
- `sorted_set`
- `sorted_map`

---

**Findings**
- Medium: `HashMap::new` docs promise a minimum capacity of 8, but the implementation only does `capacity.next_power_of_two()` so `capacity=0` yields 1 (and 1 is allowed); this diverges from the documented guarantee and can surprise users who rely on the minimum size (`hashmap/hashmap.mbt:15-45`, `builtin/int.mbt:16-41`).
- Medium: `SortedMap::range` docs say it “returns a new array”, but the function returns an `Iter2` and the inline comments invert the comparison semantics (`key > low` vs `key < low`, `key > right` vs `key > high`), which can mislead callers and future maintainers (`sorted_map/map.mbt:289-329`).
- Low: `SortedMap::keys_as_iter` returns a bare `Iter` while `values_as_iter` returns `Iter::new(...).iter()`, which is inconsistent with each other and with similar APIs in `hashmap`/`hashset` (`sorted_map/map.mbt:193-230`).
- Low: `SortedSet` uses `subset`/`disjoint`, while `HashSet` and `Set` expose `is_subset`/`is_disjoint`; this is an API naming inconsistency across the collection family (`sorted_set/set.mbt:313-331`, `hashset/hashset.mbt:380-410`, `set/linked_hash_set.mbt:581-616`).
- Low: Load factor thresholds diverge between hash-based collections (`HashMap` grows at 50% vs. `HashSet`/`Set` at ~81%), which is fine but currently undocumented and could lead to inconsistent performance expectations (`hashmap/hashmap.mbt:119`, `hashset/hashset.mbt:29,445`, `set/grow_heuristic.mbt:15-17`).

**Consistency Analysis**
- Naming and structure are broadly consistent (e.g., `new`, `from_array`, `iter`, `length`, `is_empty`), but the set APIs diverge on `subset`/`disjoint` naming and the map iterators have small inconsistencies (`sorted_set/set.mbt:313-331`, `sorted_map/map.mbt:193-230`).
- Hash-based collections share Robin Hood hashing patterns, but growth thresholds are inconsistent and not surfaced in docs, which makes cross-package behavior feel uneven (`hashmap/hashmap.mbt:119`, `hashset/hashset.mbt:29,445`).

**API Design**
- Public APIs are generally intuitive (mutating `set/add/remove`, query `contains/get`, conversions `to_array`, iterators).
- `SortedMap::range` is a good API but its current doc string describes a different return type, which can trip up users (`sorted_map/map.mbt:289-329`).
- `SortedSet` uses `subset/disjoint`, while hash-based sets use `is_subset/is_disjoint`; consider standardizing to reduce cognitive load (`sorted_set/set.mbt:313-331`, `hashset/hashset.mbt:380-410`, `set/linked_hash_set.mbt:581-616`).

**Implementation Quality**
- Hash collections: Robin Hood hashing with PSL is clear and efficient, and `shift_back`/`push_away` are cleanly implemented (`hashmap/hashmap.mbt`, `hashset/hashset.mbt`, `set/linked_hash_set.mbt`).
- Sorted collections: AVL operations are implemented coherently; `split/join` in `SortedSet` is a solid choice for union (`sorted_set/set.mbt`).
- One performance note: `SortedSet::union` recomputes size by iterating (`ret.each(...)`), which is correct but potentially avoidable if you can track size during the merge (`sorted_set/set.mbt:86-132`).

**Documentation**
- `hashmap` is heavily documented with examples; `hashset` and `set` are lighter, with some public functions having minimal or no prose (e.g., `HashSet::capacity`, `HashSet::iter`, `Set::union`).
- `SortedMap::range` documentation and inline comments are incorrect, and `HashMap::new` describes a minimum capacity that the code does not enforce (`sorted_map/map.mbt:289-329`, `hashmap/hashmap.mbt:15-45`).

**Potential Issues**
- Behavior/docs mismatch for `HashMap::new` minimum capacity (could be treated as a spec bug) (`hashmap/hashmap.mbt:15-45`).
- `SortedMap::range` documentation and comments are misleading (risk of incorrect usage/maintenance) (`sorted_map/map.mbt:289-329`).

**Suggestions**
1) Decide whether the `HashMap::new` “minimum of 8” is a real contract; if so, enforce it in code (e.g., `max(8, next_power_of_two)`), otherwise update the doc to match reality (`hashmap/hashmap.mbt:15-45`).
2) Fix `SortedMap::range` docs and inline comments to match the actual `Iter2` return and comparisons (`sorted_map/map.mbt:289-329`).
3) Standardize `SortedSet` naming to align with `is_subset`/`is_disjoint` or add aliases for consistency (`sorted_set/set.mbt:313-331`, `hashset/hashset.mbt:380-410`, `set/linked_hash_set.mbt:581-616`).
4) Align iterator-return patterns (`keys_as_iter` vs `values_as_iter`) for consistency and clarity across the collection APIs (`sorted_map/map.mbt:193-230`).
5) Document load-factor/grow thresholds for hash-based collections, or consider harmonizing them if a consistent performance profile is desired (`hashmap/hashmap.mbt:119`, `hashset/hashset.mbt:29,445`, `set/grow_heuristic.mbt:15-17`).

**Questions / Assumptions**
- Should `HashMap::new` guarantee a minimum capacity of 8, or is the doc outdated?
- Is `SortedMap::range` intended to return an iterator (current code) or an array (current docs)?
