---
name: discourse-service-authoring
description: Use when creating, editing, or reviewing Discourse service objects that include Service::Base - covers contracts, models, policies, steps, transactions, controller integration, and service specs
---

We want high quality code and very senior engineering work. Best oriented object practices are observed. Think principles like SOLID and battle-tested patterns. We also want to write idiomatic ruby. Good reference authors are Sandi Metz, Katrina Owen or Avdi Grimm. Your only source of truth to write services is the documentation at docs/developer-guides/docs/03-code-internals/19-service-objects.md, don't look at examples in the codebase.

DONT USE ANY WRITING PLAN SKILL DURING THE SESSION

## Phase 1: Deep Understanding

Build a thorough understanding of the codepath being refactored. Read every file involved: the controller action, the class method or inline logic being extracted, all models touched, guardian/policy extensions, routes, and every caller (production code, specs, import scripts, dev tools, other plugins).

## Phase 2: Assessment

Surface gaps, architectural decisions, and issues for user approval before writing any code.

- Identify logic that belongs in a model (callbacks, computed values, configuration-driven setup) rather than in the service. The service orchestrates; models own their own setup concerns.
- Split computed values across the models that own each layer. Each model should own its own configuration; higher-level models compose from lower-level ones with fallbacks.
- Extract magic numbers into named constants on the module.
- Add `-> { with_deleted }` scope to `belongs_to` associations that may reference soft-deleted records.
- Note any bugs or security issues found during research — these will be addressed during implementation.

Present all findings to the user and get approval on scope before proceeding.

## Phase 3: Implementation

Write the service, controller, update all callers, and remove dead code.

- Write model improvements first (associations, constants, extracted methods)
- Write the service class
- Write the controller integration
- Update ALL callers to use the service directly — specs, import scripts, dev tools, event handlers, other plugins. Non-controller callers use `Service.call!` (bang version). Update test `before` blocks with any site settings the service's policy requires.
- Remove dead code: if a helper method is no longer called by any production code after extraction, delete it.

## Phase 4: Service Quality Check

Review the service against these structural rules. List every violation found.

- Service name should describe the core concept business, makes 5 suggestions to the user using AskUserQuestion, don't hesitate to namespace, eg: PluginName::BusinessSubject::Action
- Steps are simple with one concern each
- Step names describe domain behavior, not code (`revoke_previous_accepted_answer` not `destroy_old_record`). ALWAYS use Discourse core domain vocabulary. Ask "why is this happening?" not "what ActiveRecord method am I calling?"
- Descriptive param names: `post_id` not `id`, `channel_id` not `target`
- `context[:]` is a code smell. Verify a `model`, `options`, or step keyword argument cannot achieve the same result. Refactoring should almost always let you use a model instead.
- `transaction` wraps ONLY DB writes that must succeed or fail together. Side effects (webhooks, events, MessageBus) live outside.
- `lock` wraps ONLY steps vulnerable to concurrent modification. Side effects are idempotent and MUST live outside the lock.
- No `return if`/`return unless` at the top of step methods — use `only_if` wrappers. Guard clauses in `only_if` predicate methods use bare `return` (not `return false`).
- NEVER have an utility methods in a service, use model or step instead
- ALWAYS Rate limiting in the controller via `before_action`
- NEVER an optional model steps just to store a value for condition checks
- `create` over `new` + separate `save!` in model steps
- Each side effect is its own step with its own `only_if` wrapper — never bundle conditional side effects with internal if-statements
- ALWAYS Group related side effects into one step ONLY when they are truly one conceptual action AND share the same condition
- No over-protection with `try` — trust internal bang methods, use non-bang persistence in model steps
- Consistent security constraints: if one MessageBus publish uses `secure_audience`, ALL publishes on that channel must
- Custom step names for model steps that CREATE (not the default `fetch_` prefix)
- When converting if/else to `only_if`, ask whether the else branch is truly conditional or default behavior that should always run
- Inline small external helper methods rather than delegating to other modules
- Idiomatic ActiveRecord: prefer association-based lookups (`target_post: record`) over foreign-key lookups
- Guard clauses in fetch methods for privilege-based branching (privileged path is the early return)
- No backward-compatible wrapper methods or `skip_policy` options
- Mutation steps ordered so rollback leaves consistent state (dependent writes after what they depend on)

Fix every violation, then re-check until clean. When in doubt AskUserQuestion.

## Phase 5: Business Logic Review

Trace every code path in the original implementation against the new service. List every bug found by criticality.

- Confirm no code path is dropped or subtly altered
- Verify side effects (DB writes, notifications, events, webhooks) fire under the same conditions and in the same order
- Check transactional boundaries: what was atomic before must remain atomic

Present bugs to the user (including bugs from the prior implementation). Fix approved items, then re-trace until clean.

## Phase 6: Security Review

Review for security concerns. List every issue found by criticality.

- Access control: are policies enforced consistently regardless of caller?
- MessageBus: secure audience applied to all publishes on secured channels?
- Data leakage: can non-privileged users infer existence of soft-deleted or private resources?

Present issues to the user. Fix approved items, then re-review until clean.

## Phase 7: Specs

Write specs following the service documentation and https://rspec.rubystyle.guide/.

- Test the contract in a separate `describe described_class::Contract` block with shoulda matchers
- Use `DiscourseEvent.track_events(:event_name) { result }` to test event triggers — NEVER manual `on`/`off`
- Use `let(:messages) { MessageBus.track_publish(channel) { result } }` as a lazy `let`
- Use fabricators for setup data, not raw `Model.create!`
- Use `:topic_with_op` fabricator when the topic needs an OP post for validations to pass
- Override `fab!` in nested contexts to change actors (e.g., `fab!(:acting_user, :admin)`) rather than overriding `let(:guardian)`
- Write model specs for any model callbacks introduced during the refactoring

Run specs and lint. Fix failures and re-run until green.

## Phase 8: Finalization

Run the full plugin spec suite and any cross-plugin specs that touch the refactored code. Lint all changed files. Verify everything is green before presenting the completed work.
