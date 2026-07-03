# RSpec Style Guide

> Source: https://rspec.rubystyle.guide/
> Last updated: 2026-02-24

## Layout

- **No blank lines** immediately after `feature`, `context`, or `describe` declarations
- **One blank line** between separate `describe`/`context` blocks; no blank line before closing `end`
- **One blank line** after `let`, `subject`, and `before`/`after` declarations before subsequent blocks
- **Group `let`/`subject` together**, separate from `before`/`after` hooks with blank lines
- **Surround multi-line declarations with blank lines** — when a `let`, `let!`, `fab!`, or `subject` uses a `do...end` or multi-line `{ }` body, put a blank line above and below it, even when adjacent declarations are single-line. Single-line declarations can still pack together, but a multi-line block always breathes on both sides:

  ```rb
  # bad — multi-line blocks stacked against neighbors
  fab!(:author)
  fab!(:topic) do
    Fabricate(:topic, user: author, title: "Hello")
  end
  fab!(:reply) do
    Fabricate(:post, topic: topic, user: author)
  end
  fab!(:tag)

  # good
  fab!(:author)

  fab!(:topic) do
    Fabricate(:topic, user: author, title: "Hello")
  end

  fab!(:reply) do
    Fabricate(:post, topic: topic, user: author)
  end

  fab!(:tag)
  ```
- **One blank line** before and after each `it`/`specify` block
- **Blank lines between logical chunks** within an example — separate setup, action, and assertion for readability

## Example Group Structure

- **First level of nesting is the method under test** — inside `RSpec.describe SomeClass`, group examples by public method: `describe "#instance_method"` / `describe ".class_method"`. Scenario `describe`/`context` blocks nest *below* the method group, never directly under the class.
- **Declaration order**: `subject` → `let!`/`let` → `before` → `after`
- **Use `context` blocks** to organize test conditions; avoid conditional logic in example descriptions
- **Pair context cases** — include both positive and negative contexts (e.g. "when present" and "when not present")
- **Use `let`** for shared data, `let!` when the value must exist even if unused in specific examples
- **Prefer `let` over instance variables** — `let(:name) { "John" }` not `before { @name = "John" }`
- **Extract shared examples** — use `shared_examples` with `it_behaves_like` to reduce duplicated test blocks
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
- **Use factories** (`FactoryBot.create`) for test data in integration tests; avoid `Model.create` and fixtures
- **Load only needed data** — minimum objects required for the test
- **Use verifying doubles** — `instance_double`, `class_double`, `object_double` over plain `double`
- **Freeze time with Timecop** — don't stub `Time.now` or `Date.today`
- **Stub HTTP requests** with WebMock or VCR
- **Don't define classes in example groups** (they leak to global scope) — use `stub_const` or `Class.new`
- **Use explicit block expectations** — `expect { do_something }.to change(...)` not implicit block subjects

## Naming

- **Context descriptions**: start with "when", "with", or "without" — e.g. `context "when the user is logged in"`
- **Example descriptions**: prefer encoding the full scenario in the `it` description rather than deeply nesting `context` blocks; limit nesting to 2 levels max
- **Keep descriptions under 60 characters**
- **Avoid "should"** — use third-person present tense: `it "returns the summary"` not `it "should return the summary"`
- **Describe methods**: `.method_name` for class methods, `#method_name` for instance methods
- **Avoid double negatives** — state the positive condition: `"returns true when status is approved or pre_approval"`, not `"returns true when status is not none"`. Be specific about the values being tested.
- **No single-letter block variables** — `|vote|`, `|option|`, not `|v|`, `|o|`.

## Expectations

- **Always use `expect` syntax** — never `should`

## Matchers

- **Use predicate matchers** — `expect(article).to be_published` not `expect(article.published?).to be true`
- **Use built-in matchers** — `expect(title).to include "lengthy"` not `expect(title.include?("lengthy")).to be true`
- **Avoid bare `be`** — use `be_truthy`, `be_nil`, `be_an(Type)` etc.
- **Extract custom matchers** for repeated expectation patterns
- **Avoid `any_instance_of`** — mock injected dependencies directly
- **Use matcher libraries** (e.g. Shoulda Matchers) for common validation checks

## Capybara

- **Use negative selectors** — `have_no_selector` not `to_not have_selector`

## Rails: Controllers

- **Mock models** in controller specs
- **Test only controller responsibilities** — method execution, assigns, render/redirect
- **Use `context` blocks** for different controller behaviors

## Rails: Models

- **Don't mock the model under test**
- **Use `FactoryBot.create`** or `subject` with new instances
- **Mocking associations is acceptable**
- **Define model once** via `let` for reuse
- **Verify factory validity** — `expect(article).to be_valid`
- **Test validations via `errors[:attribute].size`** not just `be_valid`/`not_to be_valid`
- **Separate `describe` blocks** per validated attribute
- **Name alternate objects** `another_*` for uniqueness tests

## Rails: Mailers

- **Mock models** in mailer specs
- **Verify subject, sender, recipient, and body content**

## Rails: Views

- **Mirror `app/views` structure** in `spec/views`
- **Append `_spec.rb`** to the view filename
- **Use relative view path** as outer `describe` string
- **Mock models** in view specs
- **Use `assign`** for instance variables
- **Stub helpers** on the `template` object
