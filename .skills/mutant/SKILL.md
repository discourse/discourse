---
name: mutant
description: How to run mutation testing on the migration gems and act on a surviving mutation — add a test, adopt the simpler code, or accept it as equivalent. Use when running mutant or reviewing its output.
---

# Mutation testing (mutant)

Mutant changes the code one small step at a time (`>=` → `>`, `fetch` → `[]`, a
dropped guard) and runs the covering tests. A failing test **kills** the
mutation; if all tests pass it is **alive** — that behaviour is not tested. We use
it as an audit to find weak specs, not as a gate to 100%.

How to run it, what is in scope, and the gotchas:
[references/migrations-tooling.md](references/migrations-tooling.md).

## Reading the output

```text
evil:Migrations::Conversion::Partitioner#dense?:.../partitioner.rb:78:4499a
@@ -1,7 +1,7 @@
 def dense?(min, max)
-  (max - min + 1) <= rows * DENSE_RANGE_FACTOR
+  (max + 1) <= rows * DENSE_RANGE_FACTOR
```

`-` is the real code, `+` the mutation no test caught. Mutant prints one survivor
per method, then `(N more...)` — fix it and rerun to see the next. A mutation can
also **time out** (mutated code that blocks or loops forever); that counts as
not-killed and no assertion can kill it, so treat it as equivalent.

## For each survivor, pick one

1. **Add a test** — the usual case. It must pass on the real code and fail on the
   mutation. Common gaps: only one side of a boolean tested; a one-element
   collection hiding `next` vs `break`; a stub that ignores its arguments; two
   fixtures returning the same value; a default argument every test passes.

2. **Adopt the simpler code** — when the mutation is correct for every input.
   Mutant only rewrites toward less power, so taking its form removes the
   survivor: `hash[key]` → `fetch` (key always present), `to_i` → `Integer(x)`
   (digits), `method` → `public_method` (public method), `transform_values!` →
   `transform_values` (receiver not reused), dropping a guard that can't be false.
   Don't weaken behaviour to reach 100%: keep `is_a?(Class)` / `is_a?(Array)`
   (any class / array, not the exact one), `[n, 1].max` clamps, getter/setter
   idioms. And don't just rewrite syntax to hide a mutation without a test.

3. **Accept it as equivalent** — you can't kill it and the mutant's form isn't a
   correct rewrite. Note it and move on. Don't add an ignore entry or contort a
   test just to reach 100%.

## House rules

- Prefer adding a test over changing source; keep source changes within the house
  style (no `module_function` or endless methods, `> 0` / `< 0` over `.positive?`
  / `.negative?`).
- One subject per commit; a test change separate from a source change; `MT:`
  prefix; the body says which mutation was killed and how.
- Run the gem's spec suite after a change.
