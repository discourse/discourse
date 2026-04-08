---
name: writing-rspec-tests
description: Write and structure RSpec tests for Discourse core, plugins, themes, or theme components. Use when creating or modifying model specs, controller specs, service specs, job specs, system tests, or integration tests. Covers fabricators, page objects, test structure, and theme test setup.
---

# Writing RSpec Tests

Discourse uses RSpec for testing. Follow these patterns for all test types.

## Testing Principles

- **Test behavior, not implementation** — test public interfaces; don't assert on internal state or private methods. Refactoring internals shouldn't break tests.
- **One concept per test** — each `it` block verifies one behavior for clear failure diagnosis.
- **Don't over-mock** — mock external boundaries (HTTP, third-party services), not internal collaborators. Too many mocks signals a design problem.
- **Prefer readability over DRYness** — tests are documentation. Some duplication is fine. Avoid deep `shared_examples`/`let` chains that hurt readability.
- **Test edge cases** — nil inputs, empty collections, boundary values, permission failures — not just happy paths.
- **Keep tests independent** — no test should depend on another test's execution or shared mutable state.
- **Verify placement in parent context** — before adding a new test, always read the surrounding `describe`/`context` block to confirm the test belongs there. Check that the parent context's description, `let`/`fab!` setup, and `before` hooks match the scenario being tested. A misplaced test inherits the wrong setup and produces misleading results.
- **Arrange-Act-Assert** — clear separation of setup, action, and verification in each test.
- **Don't test framework behavior** — don't test that Rails validations work; test your business logic.
- **Avoid redundant multi-layer testing** — if a model spec tests a validation, the controller spec doesn't need to re-verify that same validation logic.
- **No single-letter block variables** — use descriptive names like `|vote|`, `|option|`, not `|v|`, `|o|`.
- **Assert collections in a single assertion** — use `contain_exactly` or `eq` instead of multiple `include`/`not_to include` checks.
- **Optimise for human readability** — minimise context overload when reading an example. Avoid too many indirections.
- **Limit nesting to 2 levels** — avoid more than 2 levels of `describe`/`context` nesting. Instead of deeply nested contexts, put the full scenario description in the `it` block itself. Flat tests are easier to read and maintain.
- **Avoid double negatives in descriptions** — write test descriptions that state the positive condition. For example, prefer `"returns true when topic_approval_type is approval or pre_approval"` over `"returns true when topic_approval_type is not none"`. Be specific about the values being tested.

## Style Guide Reference

Before writing any RSpec code, read [references/rspec-style-guide.md](references/rspec-style-guide.md) and apply those conventions alongside the Discourse-specific patterns below.

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

## Test Efficiency

Tests have setup overhead. **Optimize for the fewest test examples possible:**

- Combine related assertions in a single `it` block when testing the same page/state
- Avoid separate tests for trivial variations
- Each `it` block incurs setup overhead; batch checks where logical

## Running Tests

```sh
# Run specific file
bin/rspec spec/models/topic_spec.rb

# Run specific line
bin/rspec spec/models/topic_spec.rb:15
```

## Specialized Test Types

- **System tests**: See [references/system-tests.md](references/system-tests.md) for file naming, test structure, page objects, and scoping patterns.
- **Theme/component tests**: See [references/theme-tests.md](references/theme-tests.md) for theme upload helpers, settings, and directory structure.
