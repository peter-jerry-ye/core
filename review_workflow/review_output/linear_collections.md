# Review: Linear Collections

**Packages:**
- `list`
- `deque`
- `queue`
- `priority_queue`
- `array`

---

Using skill: moonbit-agent-guide (reviewing MoonBit packages and conventions).

**Findings**
- Deque::drain accepts negative `start`/`len`, which can drive invalid slice math and `UninitializedArray::make(len)` with a negative size. `deque/deque.mbt:1892-1904` (`start` only checked `>= self.len`, `len` only clamped by `<= max_len`). This is a correctness bug for calls like `drain(start=-1, len=2)` or `drain(start=0, len=-1)`.
- Unsafe API visibility is inconsistent in `list`: `List::unsafe_tail` is public and documented (no `#internal` / `#doc(hidden)`), while `unsafe_head`/`unsafe_last` are hidden. This exposes a panic‑prone API in docs unexpectedly. `list/list.mbt:430-463`.

**Consistency analysis**
- Naming is mostly consistent: `new`, `from_array`, `length`, `is_empty`, `to_array` where applicable. Type aliases `#alias(T, deprecated)` are consistent across list/deque/queue/priority_queue.
- Method style diverges: `list` is persistent/functional (`cons`, `prepend`, `concat`), `deque`/`queue`/`priority_queue` are mutable with in‑place operations (`push_*`, `pop_*`). This is fine, but cross‑package surface shape differs (e.g., `@array.zip_with` is a free function while list has `List::zip`).
- Unsafe naming is mostly consistent (`unsafe_*`), but visibility differs (see finding for `unsafe_tail`).

**API design**
- Public API is broad and generally intuitive. `deque` is the most feature‑rich and aligns with a VecDeque‑like design, `queue` is minimal FIFO, `priority_queue` is a max‑heap/heap queue.
- `priority_queue` iteration (`iter`) is defined in terms of `to_array()` which sorts and reverses each time. That is a potentially surprising O(n log n) iterator for a type that otherwise offers O(log n) operations. Consider documenting the cost or providing a cheaper traversal iterator.
- `array` exposes only `zip_with` as a free function. For consistency with the rest of the group, consider a method style (`Array::zip_with`) or a symmetric `zip` helper.

**Implementation quality**
- `list` implementations are careful about allocation and avoid repeated traversal. The `reverse_in_place` helper is private and used safely (e.g., `zip`).
- `deque` core operations (push/pop, index ops, `as_views`) are clear and reflect ring-buffer invariants. `append` handles aliasing defensively by capturing `other`’s state first.
- `priority_queue` uses a pairing heap approach; `meld`/`merges` are compact and correct, but iteration requires full sort.
- `queue` is a straightforward singly-linked queue with O(1) push/pop.

**Documentation**
- `list` and `deque` are exceptionally well documented with examples; `queue` and `priority_queue` are decent but have some undocumented impls (e.g., `Queue`’s `Eq` impl).
- `array/view.mbt` is minimal and uses `#deprecated` without a message; it’s consistent with other deprecated aliases but could use a short reason.

**Potential issues**
- Deque::drain parameter validation (negative `start`/`len`) is a correctness issue. `deque/deque.mbt:1892-1904`.
- `List::unsafe_tail` is visible and documented while other unsafe methods are hidden; this is a public API surprise and inconsistent with other packages. `list/list.mbt:430-463`.

**Suggestions**
1. Add explicit guards in `Deque::drain` for `start < 0` and `len < 0` (when provided) and return empty or abort consistently. This avoids undefined behavior paths. `deque/deque.mbt:1892-1904`.
2. Align unsafe API visibility in `list` by adding `#internal(unsafe, ...)` + `#doc(hidden)` to `List::unsafe_tail`, or expose all unsafe methods consistently. `list/list.mbt:430-463`.
3. Document `PriorityQueue::iter`/`to_array` cost (O(n log n)) or add a non‑sorting traversal iterator to avoid surprising performance. `priority_queue/priority_queue.mbt:46-78`.
4. Consider adding a method-style `Array::zip_with` (or a `zip`) to align with the `List::zip` method and deques’ method style. `array/array.mbt:23-38`.
5. Optional: fill in `deque/deprecated.mbt` and `queue/deprecated.mbt` or remove if intentionally empty, to match the “deprecated blocks live in deprecated.mbt” convention consistently.

If you want, I can draft the fixes for the `Deque::drain` validation and the `List::unsafe_tail` visibility.
