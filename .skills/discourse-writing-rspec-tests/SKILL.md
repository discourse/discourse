---
name: discourse-writing-rspec-tests
description: Write and structure RSpec tests for Discourse core, plugins, themes, or theme components. Use when creating or modifying model specs, controller specs, service specs, job specs, system tests, or integration tests. Covers fabricators, page objects, test structure, and theme test setup.
---

# Writing RSpec Tests

Discourse uses RSpec at every layer — models, requests, services, jobs, system tests. This skill is the *judgment* for writing them. Mechanical style rules (layout, naming, matchers, nesting) live in [references/rspec-style-guide.md](references/rspec-style-guide.md); read it before writing.

## The core idea: test the interface, not the innards

A spec pins down a method's **public interface** — the messages you send it and what you observably get back — so the implementation underneath stays free to change. (Sandi Metz, *The Magic Tricks of Testing*.) Choose what to assert by the kind of message:

- **Query (returns a value, changes nothing)** — assert the **return value**.
- **Command (changes state)** — assert the **direct public side effect** it owns: persisted columns, an enqueued job, an emitted event, a response body, rendered DOM. Drive the public entry point and check the state it left behind; that entry point names the spec's group — `describe "#execute"` for a job, `".call"` for a service, `"#expire!"` for a model command.
- **Private method (a message to self)** — don't test it, don't assert it was called. `expects(:internal)` / `.to receive(:internal)` on the object under test freezes tomorrow's refactor. This is the anti-pattern.
- **Outgoing query (to a collaborator)** — don't assert on it; the collaborator's own spec owns it.
- **Outgoing command (to a collaborator)** — the only observable fact is *that it was sent*, so assert that with the capture helpers `DiscourseEvent.track_events` / `MessageBus.track_publish`, never `expects(:trigger)` / `expects(:publish)`.

The throughline: **test the messages crossing the public boundary; ignore what happens inside.** A test that breaks only because you renamed a private method or reordered internal calls — with no change to the return value or persisted state — is testing the wrong thing.

## Principles that follow

- **One behavior per example** — a failure should name its cause. (Batch assertions about the *same* state; see Cost.)
- **Assert observable outcomes, including edge cases** — nil, empty, boundary, permission failures, not just the happy path. Don't test framework behavior (Rails validations work; your logic is what's under test).
- **Each layer asserts what it owns** — models own validations/scopes/persisted state; services own orchestration/authorization/return values; request specs own HTTP status and response shape; jobs own enqueue/idempotency. Don't re-assert a lower layer's contract from above — trust it. (Callbacks belong to the model that defines them: drive the public op that fires them; never `describe "after_commit :x"`.)
- **Readable beats DRY; flat beats nested** — tests are documentation. Some duplication is fine; deep `shared_examples`/`let` chains and more than two levels of `describe`/`context` nesting are not — push the scenario into the `it` description instead.
- **Keep assertions in sync with the data** — match collections exactly (`contain_exactly`/`eq`, not a pile of `include`s), and reference the object under test, not a copied string literal that silently rots (`not_to include(private_post.raw)`, not a hardcoded `"..."`).
- **Place each test where its setup fits** — read the surrounding `describe`/`before`/`fab!` before adding an example; a misplaced test inherits the wrong world.

## Test data: fabricators

`fab!` for shared data, `Fabricate` inline for one-off data — **never** a `before` block to fabricate; `let!` only when truly needed. Fabricators live in `spec/fabricators/` (core and each plugin) — grep before assuming none exists or hand-rolling setup.

Name a fixture for the role it plays at the call site (`fab!(:topic_creator)`, not `fab!(:user)`). For a recurring non-default variant, declare a derived fabricator (`Fabricator(:variant, from: :base)`) named for its *data state* — reusable across tests — rather than an ad-hoc helper named after one test's scenario.

## Cost: the cheapest test that proves the behavior

Every example has setup cost; system tests cost orders of magnitude more.

- Batch assertions about the same page/state into one example; don't split trivial variations.
- **One system test per user flow, not per internal code path.** If two scenarios look the same to the user but differ only in internals, test the flow once and cover the branches with cheaper unit/component tests.

## Running tests

```sh
bin/rspec spec/models/topic_spec.rb        # a file
bin/rspec spec/models/topic_spec.rb:15     # one example
SELENIUM_HEADLESS=0 bin/rspec spec/system/my_spec.rb   # visible browser
```

## Where to go next

- Request specs → [references/request-specs.md](references/request-specs.md)
- System tests → [references/system-tests.md](references/system-tests.md)
- Theme / component tests → [references/theme-tests.md](references/theme-tests.md)
- Capturing events / publishes / SQL → [references/tracking-helpers.md](references/tracking-helpers.md)
- General RSpec style → [references/rspec-style-guide.md](references/rspec-style-guide.md)
