---
name: discourse-writing-rspec-tests
description: Write and structure RSpec tests for Discourse core, plugins, themes, or theme components. Use when creating or modifying model specs, controller specs, service specs, job specs, system tests, or integration tests. Covers fabricators, page objects, test structure, and theme test setup.
---

# Writing RSpec Tests

Discourse uses RSpec for testing. Follow these patterns for all test types.

## Testing Principles

- **Test behavior, not implementation** — test public interfaces; don't assert on internal state or private methods. Refactoring internals shouldn't break tests.
- **Choose assertions at the public boundary** — for a query, assert its return value. For a command, drive its public entry point and assert the direct side effect it owns: persisted state, an enqueued job, an emitted event, a response body, or rendered output. Group class, service, job, and model specs by that entry point (`describe ".call"`, `describe "#execute"`, or `describe "#expire!"`).
- **One concept per test** — each `it` block verifies one behavior for clear failure diagnosis.
- **Don't over-mock** — mock external boundaries (HTTP, third-party services), not internal collaborators. Too many mocks signals a design problem.
- **Don't assert that internal methods are or aren't called** — assertions like `SomeService.expects(:some_method).never` (or `.once`, `.with(...)`) couple the test to internal implementation details that the caller shouldn't care about. Assert on the observable outcome instead: returned value, persisted state, emitted event, response body, rendered output. If the implementation is later refactored, inlined, or renamed, a behavior-focused test still passes when the behavior is correct.
- **Capture infrastructure side effects without mocking internals** — use `DiscourseEvent.track_events` and `MessageBus.track_publish` when asserting emitted events or published messages instead of expecting calls to `trigger` or `publish`.
- **Prefer readability over DRYness** — tests are documentation. Some duplication is fine. Avoid deep `shared_examples`/`let` chains that hurt readability.
- **Test edge cases** — nil inputs, empty collections, boundary values, permission failures — not just happy paths.
- **Keep tests independent** — no test should depend on another test's execution or shared mutable state.
- **Verify placement in parent context** — before adding a new test, always read the surrounding `describe`/`context` block to confirm the test belongs there. Check that the parent context's description, `let`/`fab!` setup, and `before` hooks match the scenario being tested. A misplaced test inherits the wrong setup and produces misleading results.
- **Arrange-Act-Assert** — clear separation of setup, action, and verification in each test.
- **Don't test framework behavior** — don't test that Rails validations work; test your business logic.
- **Each layer asserts what it owns** — models own validations, scopes, callbacks, and persisted state; services own orchestration, authorization, and return values; request specs own the HTTP contract and externally visible effects of the action; jobs own execution behavior and any required idempotency. Don't re-assert a lower layer's contract from above. Test callbacks through the public operation that invokes them, not with a group such as `describe "after_commit :callback_name"`.
- **No single-letter block variables** — use descriptive names like `|vote|`, `|option|`, not `|v|`, `|o|`.
- **Assert collections in a single assertion** — use `contain_exactly` or `eq` instead of multiple `include`/`not_to include` checks.
- **Reference objects, not literal strings, in negative assertions** — `expect(response.body).not_to include("hidden data explorer excerpt")` silently passes if the literal has a typo or drifts from the source, giving a false sense of security. Reference the object directly (`expect(response.body).not_to include(private_post.raw)`) so the assertion stays in sync with the data under test. The same applies to any `not_to include`/`not_to match` against hardcoded strings.
- **Optimise for human readability** — minimise context overload when reading an example. Avoid too many indirections.
- **Limit nesting to 2 levels** — avoid more than 2 levels of `describe`/`context` nesting. Instead of deeply nested contexts, put the full scenario description in the `it` block itself. Flat tests are easier to read and maintain.
- **Avoid double negatives in descriptions** — write test descriptions that state the positive condition. For example, prefer `"returns true when topic_approval_type is approval or pre_approval"` over `"returns true when topic_approval_type is not none"`. Be specific about the values being tested.

## Spec Structure

Arrange class, model, service, job, and request specs from public entry point to scenario to expected behavior:

```rb
RSpec.describe ExpiryPolicy do
  describe "#expired?" do
    context "when the expiry time has passed" do
      subject(:expiry_policy) { described_class.new(expires_at: 1.hour.ago) }

      it "returns true" do
        expect(expiry_policy.expired?).to eq(true)
      end
    end
  end
end
```

- The first group inside `RSpec.describe` identifies the public entry point under test: `describe "#instance_method"`, `describe ".class_method"`, or `describe "#controller_action"`.
- Nest scenario `context` blocks below the entry-point group, never directly below the class. System and integration specs that do not exercise a single public method may instead group by user-facing flow or behavior.
- Put an `it` block directly below the entry-point group when no scenario grouping is needed; otherwise, put it inside the relevant `context`.
- Start context descriptions with `"when"`, `"with"`, or `"without"`. Write `it` descriptions in the third-person present tense without `"should"`.
- Limit nesting below `RSpec.describe` to the entry-point group and one scenario group. Put additional scenario detail in the `it` description instead of adding another context.
- Within a group, order declarations and hooks as `subject`, `fab!`/`let!`/`let`, `before`, then `after`, followed by examples and nested contexts.
- Do not leave a blank line immediately after a `describe` or `context` declaration or before its closing `end`. Group single-line declarations together. Separate declaration groups, hook groups, each example, and each sibling group with one blank line; surround multi-line declarations with blank lines. Also separate arrange, act, and assert sections within an example.

## Test Data with Fabricators

Use `fab!` for shared test data, or `Fabricate` inline within the test example:

```rb
fab!(:user)
fab!(:category)
fab!(:tag)
fab!(:topic) { Fabricate(:topic, category: category, tags: [tag]) }

it "displays the topic" do
  sign_in(user)
  visit("/")
end

it "creates a new topic" do
  new_category = Fabricate(:category, name: "Special")
  # ... test using new_category
end
```

Never use `before` blocks for Fabricate calls. Use `let!` only when absolutely necessary.

Fabricators live in `spec/fabricators/` in core and each plugin. Search for an existing fabricator before hand-rolling setup. Name shared data for the role it plays (`fab!(:topic_creator)`, not `fab!(:user)`). For recurring non-default data, define a derived fabricator (`Fabricator(:variant, from: :base)`) named for its data state rather than adding a scenario-specific helper.

## Test Efficiency

Tests have setup overhead. **Optimize for the fewest test examples possible:**

- Combine related assertions in a single `it` block when testing the same page/state
- Avoid separate tests for trivial variations
- Each `it` block incurs setup overhead; batch checks where logical
- Use one system test per user flow, not per internal code path. If scenarios look the same to the user but differ internally, test the flow once and cover the branches with cheaper tests.

## Running Tests

```sh
# Run specific file
bin/rspec spec/models/topic_spec.rb

# Run specific line
bin/rspec spec/models/topic_spec.rb:15
```

## Specialized Test Types

- **Request specs**: See [references/request-specs.md](references/request-specs.md) for controller/request spec structure, action-based `describe` grouping, and what to assert.
- **System tests**: See [references/system-tests.md](references/system-tests.md) for file naming, test structure, page objects, and scoping patterns.
- **Theme/component tests**: See [references/theme-tests.md](references/theme-tests.md) for theme upload helpers, settings, and directory structure.

## Tracking Helpers

See [references/tracking-helpers.md](references/tracking-helpers.md) for `DiscourseEvent.track_events`, `MessageBus.track_publish`, and `track_sql_queries` — block helpers that capture events, message-bus publishes, and SQL queries so tests can assert on side effects.
