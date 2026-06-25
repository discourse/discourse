---
name: mutant
description: Run mutant, read mutation reports, fix alive mutations, and verify coverage. Use when running mutation testing or responding to alive mutations.
compatibility: Unified agent skills CLI
metadata:
  author: dkubb
  version: "2026-03-v22"
triggers:
  - "mutation testing"
  - "mutant"
  - "alive mutation"
  - "mutation coverage"
---

# Mutant

## When to Activate

- The user asks to run mutation testing.
- The user has alive mutations to fix.
- The user asks to verify mutation coverage.

## When Not to Use

- The task does not involve mutation testing.

## Inputs

- Alive mutation output to act on.

## Outputs (Fixed Order)

1. Mutation results (alive count, coverage percentage).
2. Action for each alive mutation.

## Reading Output

An alive mutation looks like:

```text
evil:YourClass#method:YourClass#method:lib/your_class.rb:42:abc12
@@ -1,3 +1,3 @@
 def method
-  @value >= threshold
+  @value > threshold
 end
```

- `evil` means no test killed this mutation.
- The diff shows original (minus) and mutated (plus) code.

## Reporting Format

Lead with the verdict (BLUF — bottom line up front):

**If unkillable:**

> **Unkillable.** Both forms are equivalent because \[reason\].
> Add to ignore list.

**If killable:**

> **Killable.**
>
> **Option A — add test:**
>
> ```diff
> (test diff)
> ```
>
> **Option B — simplify code:**
>
> ```diff
> (source diff)
> ```

Always present both options together so the user can choose. Include
evidence: if you cannot think of a test that would kill the mutation,
say so — that is valuable signal toward unkillable.

## Fixing Alive Mutations

For each alive mutation, read the diff, then read the source and
existing tests. Ask: "is the mutated code acceptable?" Then choose:

1. **Add a test** when the mutated code is wrong but the tests do
   not prove it. The test must pass with the original code and fail
   with the mutated code. Common reasons a test is missing:

   - Only one value of a boolean/flag is tested (add the other).
   - A collection has one element, so `next` and `break` behave the
     same (add a test with multiple elements).
   - Two objects return the same value in test data, hiding which one
     the code actually uses (add test data where they differ).
   - A method has a default parameter value, and all tests pass the
     argument explicitly, leaving the default path uncovered (add a
     test that omits the argument).

2. **Simplify the code** when the mutated code is correct for all
   valid inputs. Apply the mutation's change directly to the source
   code — do not restructure or rewrite, just accept the mutated
   form.

### How Simplification Works

Mutant encodes the **principle of least power**: use the most
constrained primitive that satisfies the requirement. When Ruby
offers multiple methods that overlap in behavior but differ in
power, mutant replaces the more powerful one with the less powerful
one. If the tests still pass, you did not need the extra power —
accept the simpler form. If a test fails, the test proves you
needed the more powerful primitive.

Before accepting a simplification, verify the mutation preserves
behavior across the method's full input domain and all call sites.

### Simplification Trap: Syntax Rewriting

Do not rewrite code to eliminate a mutation axis without first
ensuring the expression has test coverage. Changing syntax (e.g.
replacing `&method(:name)` with `{ |x| name(x) }`) may make the
mutation disappear, but it does not prove the code is correct — it
just hides the gap. The correct sequence is:

1. Add test coverage for the expression (e.g. a meta spec or
   integration test that exercises the code path).
2. Apply the simplification that mutant suggests (e.g. `method` →
   `public_method`).
3. Verify 100% mutation coverage on the subject.

If a simplification removes a mutation axis, the underlying
expression must still be reachable by tests. Every code path that
mutant can mutate must have at least one test that exercises it.

### When a Mutation Is Equivalent

When the original and mutated code produce the same result for all
inputs, the mutation is **equivalent**. Equivalent does NOT mean
unkillable. Ask: does the mutated form use a more constrained
primitive? If yes, it IS the simplification — apply it to the
source. Examples: `method` → `public_method` (restricts to public
API), `kind_of?` → `instance_of?` (restricts to exact class).

A mutation is only **unkillable** when you cannot add a test AND
you cannot apply the mutation to the source (e.g. both forms call
through to the same underlying method with no way to prefer either).

When unkillable:

1. Add the subject to the ignore list with an inline comment
   explaining why it is unkillable.
2. Do not commit code or test changes for this subject.
3. Report: which mutation survived, why it is equivalent, and what
   you tried before concluding it is unkillable.

Every ignored subject must have a comment. No uncommented entries.

## Usage

1. Run mutant:

   ```sh
   bundle exec mutant run --fail-fast
   ```

   When the subject is already known, scope the run to avoid
   testing unrelated subjects:

   ```sh
   bundle exec mutant run --fail-fast 'Foo::Bar#baz'
   ```

   If the command succeeds, coverage is 100% — done.
   If it fails, find the `evil:` line in the output — it has the
   subject name, file path, and line number. The diff block
   immediately after shows the original and mutated code.

2. Read the source file and existing test file for the subject.

3. Decide: add test or simplify code. Make the change. Do not change
   both code and tests in the same commit — if both need changing,
   commit the test first, then simplify the code in a second commit.

4. Re-run mutant (repeat step 1) until 100%. If the same mutation
   survives after 2 attempts, evaluate whether it is unkillable (see
   "When a Mutation Is Equivalent" above).

5. Run the project test suite.

6. Commit the change. Follow the project's commit message
   conventions, defaulting to conventional commits if none are
   present. The commit body must explain why the change was made
   with enough detail for effective code review — which mutation
   survived, why the test kills it or why the simplification is
   correct.

### Prepare Legacy Project

When adding mutant to a project that has no ignore list yet,
run mutant once to find all alive subjects, then seed the ignore
list so the burn-down process can start from a passing baseline:

```sh
bundle exec mutant run 2>&1 \
  | sed -n 's/^evil:\([A-Za-z][A-Za-z0-9_:]*[#.][^:]*\):.*/\1/p' \
  | LC_ALL=C sort -u \
  || true
```

The `sed` pattern extracts the subject expression (e.g.
`Axiom::Foo#bar`) from each `evil:` line, handling `::` in
namespaced constants. The evil line format is:

```text
evil:SUBJECT:SOURCE_LOC:FILE:LINENO:ID
```

Add each subject to the `ignore` list in the mutant config with an
inline comment (e.g. `# legacy baseline`) and commit as a baseline. Then remove one subject at a time from
the ignore list and follow the Usage instructions above to kill
its alive mutations. Commit each subject's fix with the ignore
list removal included.

## Checklist

- Each alive mutation has a clear action: add test or simplify code.
- New tests fail against the mutated code, not just pass against the
  original.
- The project test suite passes after each change.
- Each commit touches one subject only.
- Report what you did and why so the user can review your decisions:

  - Research before asking. If a question depends on information you
    can gather first, gather it — then ask an informed question
    instead of a speculative one.

  - If unkillable, say so up front. Do not bury the verdict in
    analysis the reader cannot act on.

  - If killable, present the options clearly: add a test (Option A)
    or simplify the code (Option B). See "Reporting Format" above.
