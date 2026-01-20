# Review: Regex Engine Core

**Packages:**
- `internal/regex_engine`
- `internal/regex_engine/automata`
- `internal/regex_engine/ast`
- `internal/regex_engine/symbol_map`
- `internal/regex_engine/shared_types`

---

Using the moonbit-agent-guide for this MoonBit review.

**Findings**
- High: Dense symbol table indexing ignores `lb`, so non-zero valid ranges can crash. `SymbolMap::finalize_dense` writes `table[c]` with `table` sized `ub - lb + 1`, and `DenseTable::map` indexes `self.0[c]` directly. Any profile where `lb != 0` (e.g., restricted subrange) will index out of bounds. See `internal/regex_engine/symbol_map/symbol_map.mbt` and `internal/regex_engine/symbol_map/dense_table.mbt`.
- High: Line boundary assertions only split on `'\n'`, so `StartOfLine`/`EndOfLine` can misbehave if `profile.category` treats other line terminators as newline. `symbolize` hardcodes `RecharSet::char('\n')` instead of using `profile.line_terminator`, which means categories may collapse in `symbol_repr` for `\r`, `\u2028`, etc. See `internal/regex_engine/symbolize.mbt`.
- Medium: `Pattern::is_anchored` treats any anchored node in a `Sequence` as anchoring the whole sequence. That can incorrectly skip the implicit `.*?` prefix for patterns where `^` is not first (or for non-parser-built ASTs). See `internal/regex_engine/ast/pattern.mbt`.
- Medium: `iter` in `translate` is recursive; large `{n,m}` quantifiers can overflow the stack. See `internal/regex_engine/translate.mbt`.
- Low: `Regex::execute` uses `lastIndex` camelCase while the rest of the API uses snake_case (`group_names`, `start_of_input`). See `internal/regex_engine/execute.mbt`.
- Low: Public `quantifier` accepts `Quantifier`, but `Quantifier` is `pub(all)` so external users can’t construct it even though the function is `pub`. See `internal/regex_engine/ast/pattern.mbt`.

**Consistency analysis**
- Style is largely consistent: snake_case for functions/values, UpperCamel for types/enums, block separators `///|` throughout.
- The primary inconsistency is `lastIndex` in `Regex::execute` vs snake_case elsewhere. `pub` vs `pub(all)` is also uneven (e.g., `Quantifier` vs `Pattern`).

**API design**
- The constructor-style `ast` API (`char`, `seq`, `alt`, `quantifier`, `capture`) is clear and composable.
- `Regex::execute` returning `MatchResult?` with `group(index)` is intuitive. Consider whether `Quantifier` should be public or replace `quantifier(expr, q)` with `quantifier(expr, min, max?, mode)` for more ergonomic use outside the module.
- `SymbolMap::finalize` returning `&Table` is convenient but hides the required `lb` offset (see bug above); a dedicated `DenseTable` that stores `lb` would be clearer and safer.

**Implementation quality**
- The automata core is well-structured, with good memoization (`state_table`, cached transitions) and deterministic priority handling in `ThreadSet`.
- The `MarkSlotMap`/`Positions` pipeline is clear and efficient for captures.
- The `symbol_map` design is good, but the dense path has a correctness bug for non-zero `lb`, and `symbolize` doesn’t fully respect `Profile` for line terminators.

**Documentation**
- Excellent documentation in `automata` (e.g., `expr.mbt`, `state.mbt`, `thread_set.mbt`).
- Sparse docs in `ast`, `shared_types`, and `symbol_map`. Public items like `Pattern`, `QuantifierMode`, `Preference`, and `SymbolMap::finalize` would benefit from short docstrings and a couple of examples. `Profile::new` and `RecharSet::char_range` panic conditions are undocumented.

**Potential issues**
- Non-zero `lb` in `SymbolMap::finalize_dense` can panic at runtime.
- Line terminator handling is incomplete if `profile.category` treats `\r` or Unicode line separators as newline.
- `Pattern::is_anchored` may under-approximate when ASTs are constructed programmatically.
- Very large quantified repetitions can overflow the stack due to recursive `iter`.

**Suggestions**
1. Fix dense table indexing by storing `lb` in `DenseTable` and indexing with `c - lb`, or allocate `table` to size `ub + 1` and accept the memory cost. Update both `SymbolMap::finalize_dense` and `DenseTable::map`.
2. In `symbolize`, split on `profile.line_terminator` instead of `RecharSet::char('\n')`, and consider splitting on any set that influences `profile.category` (e.g., `word` + `line_terminator`).
3. Revisit `Pattern::is_anchored` to use “anchored at start” logic for sequences (e.g., check only the first element or encode a dedicated `StartOfInput` flag in AST).
4. Replace recursive `iter` with a loop to avoid deep recursion on large quantifier bounds.
5. Normalize `lastIndex` → `last_index` for API consistency, or provide a named parameter alias if this mirrors external API.
6. Add minimal docstrings for shared types (`Profile`, `Category`, `Preference`, `QuantifierMode`) and for `SymbolMap::finalize`, including panic conditions.

**Questions / assumptions**
- Is the engine intended to operate on UTF-16 code units (current `StringView` indexing) rather than Unicode scalar values? If not, this needs a conversion layer or `StringView.get_char`.
- Is it a deliberate assumption that `Profile.valid` always starts at 0? If so, the dense table bug may be “by design,” but it should be documented.

If you want, I can propose targeted tests for the dense-table offset and multi-line terminator behavior.
