# RSpec Style Guide

> Adapted from: https://rspec.rubystyle.guide/

## Layout

- **No blank lines** immediately after `feature`, `context`, or `describe` declarations
- **One blank line** between separate `describe`/`context` blocks; no blank line before closing `end`
- **One blank line** after `let`, `subject`, and `before`/`after` declarations before subsequent blocks
- **Group `let`/`subject` together**, separate from `before`/`after` hooks with blank lines
- **One blank line** before and after each `it`/`specify` block
- **Blank lines between logical chunks** within an example — separate setup, action, and assertion for readability

## Example Group Structure

- **Declaration order**: `subject` → `fab!`/`let!`/`let` → `before` → `after`
- **Use `context` blocks** to organize test conditions; avoid conditional logic in example descriptions
- **Pair context cases** — include both positive and negative contexts (e.g. "when present" and "when not present")
- **Use `fab!`** for shared test data, `let` for computed values or non-persisted objects
- **Prefer `let` over instance variables** — `let(:name) { "John" }` not `before { @name = "John" }`
- **Omit `:each`/`:example`** scope on `before`/`after`/`around` hooks (they're the default)
- **Use `:context` over `:all`** when specifying hook scope
- **Minimize `:context`-scoped hooks** to prevent state leakage

## Example Structure

- **One expectation per example** or use `aggregate_failures` tag for multiple expectations; apply consistently
- **Use `subject`** to eliminate repetition when multiple tests reference the same object
- **Name subjects explicitly** — `subject(:article) { ... }` not anonymous `subject { ... }` (unless using `is_expected`)
- **Use distinct subject names** across different contexts for clarity
- **Never stub methods on the subject** — adjust initialization or create a presenter instead
- **Use `specify`** for tests without descriptions; use `it` for described examples
- **Don't generate tests via iteration** — write each test explicitly
- **Avoid incidental state** — use matchers like `change` instead of depending on shared state
- **Balance DRY with clarity** — some duplication in tests is preferable to fragile shared setup
- **Load only needed data** — minimum objects required for the test
- **Freeze time with `freeze_time`** — don't stub `Time.now` or `Date.today`
- **Stub HTTP requests** with WebMock
- **Don't define classes in example groups** (they leak to global scope) — use `stub_const` or `Class.new`
- **Use explicit block expectations** — `expect { do_something }.to change(...)` not implicit block subjects

## Naming

- **Context descriptions**: start with "when", "with", or "without" — e.g. `context "when the user is logged in"`
- **Example descriptions**: prefer encoding the full scenario in the `it` description rather than deeply nesting `context` blocks; limit nesting to 2 levels max
- **Keep descriptions under 60 characters**
- **Avoid "should"** — use third-person present tense: `it "returns the summary"` not `it "should return the summary"`
- **Describe methods**: `.method_name` for class methods, `#method_name` for instance methods

## Expectations

- **Always use `expect` syntax** — never `should`

## Matchers

- **Use predicate matchers** — `expect(article).to be_published` not `expect(article.published?).to be true`
- **Use built-in matchers** — `expect(title).to include "lengthy"` not `expect(title.include?("lengthy")).to be true`
- **Avoid bare `be`** — use `be_truthy`, `be_nil`, `be_an(Type)` etc.
- **Extract custom matchers** for repeated expectation patterns
- **Avoid `any_instance_of`** — mock injected dependencies directly

## Capybara

- **Use negative selectors** — `have_no_selector` not `to_not have_selector`
