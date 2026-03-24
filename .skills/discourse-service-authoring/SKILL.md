---
name: discourse-service-authoring
description: Use when creating, editing, or reviewing Discourse service objects that include Service::Base - covers contracts, models, policies, steps, transactions, controller integration, and service specs
---

We want high quality code and very senior engineering work. Best oriented object practices are observed. Think principles like SOLID and battle-tested patterns. We also want to write idiomatic ruby. Good reference authors are Sandi Metz, Katrina Owen or Avdi Grimm. Your only source of truth to write services is the documentation at docs/developer-guides/docs/03-code-internals/19-service-objects.md, don't look at examples in the codebase.

DONT USE ANY WRITING PLAN SKILL DURING THE SESSION

## Autonomous Mode

When the user says "autonomous mode" (or similar), apply these overrides:
- Do NOT use AskUserQuestion — make your best judgment call and state what you chose
- Do NOT wait for user approval at phase gates — present the deliverable and proceed immediately
- Still present audit tables, but fix all FAILs and continue without waiting for confirmation
- Still present service name suggestions, but pick the best one yourself

## Task Tracking

**MANDATORY:** At the start of every session using this skill, create a task for each phase using TaskCreate:

1. "Phase 1: Deep Understanding"
2. "Phase 2: Assessment"
3. "Phase 3: Implementation"
4. "Phase 4: Quality"
5. "Phase 5: Business logic"
6. "Phase 6: Security"
7. "Phase 7: Specs"
8. "Phase 8: Finalization"

Create ALL tasks upfront before starting any work. Mark each task as `in_progress` when you begin it and `completed` when the user approves the phase gate.

## Execution Discipline

Every phase is a discrete step. Complete one phase fully before starting the next. Each phase ends with a user-visible deliverable — findings, an audit table, or a confirmation. NEVER silently advance to the next phase.

**Review phases (4, 5, 6) use a strict audit loop:**
1. Evaluate every rule in the phase's checklist against the current code
2. Present a numbered verdict table — one row per rule, each with PASS / FAIL / NA and a one-line evidence citation (file:line or brief rationale)
3. If any FAIL: fix the violations, then go back to step 1 and re-evaluate the **full** checklist (not just the items you fixed)
4. The phase ends only when the user sees an all-PASS table and approves

**Audit table format** (used by phases 4, 5, 6):

```
| # | Rule | Verdict | Evidence |
|---|------|---------|----------|
| 1 | Service name describes core business concept | PASS | `Chat::Message::Trash` — uses domain vocabulary |
| 2 | Steps have one concern each | FAIL | `update_message` both validates and persists |
| 3 | No utility methods in service | NA | No utility methods present |
```

- **Every rule in the phase's checklist gets a row** — no omissions
- **FAIL rows must cite file:line** where the violation occurs
- **PASS rows need brief evidence** — not just "looks good" but what you actually verified
- **NA requires justification** — why the rule doesn't apply to this service
- After fixes, produce a **complete new table** (not a diff or "fixed items only")

## Phase 1: Deep Understanding

Build a thorough understanding of the codepath being refactored. Read every file involved: the controller action, the class method or inline logic being extracted, all models touched, guardian/policy extensions, serializers, routes, and every caller (production code, specs, import scripts, dev tools, other plugins).

**Gate:** Present a summary to the user listing every file read and the key responsibilities discovered. Wait for user confirmation that the understanding is complete before proceeding to Phase 2.

## Phase 2: Assessment

Surface gaps, architectural decisions, and issues for user approval before writing any code.

- Identify logic that belongs in a model (callbacks, computed values, configuration-driven setup) rather than in the service. The service orchestrates; models own their own setup concerns.
- Split computed values across the models that own each layer. Each model should own its own configuration; higher-level models compose from lower-level ones with fallbacks.
- Extract magic numbers into named constants on the module.
- Add `-> { with_deleted }` scope to `belongs_to` associations that may reference soft-deleted records.
- Note any bugs or security issues found during research — these will be addressed during implementation.
- Identify any plain-class serializers (not inheriting from ApplicationSerializer) and flag them for conversion to ActiveModel::Serializer.

Present all findings to the user and get approval on scope before proceeding.

## Phase 3: Implementation

Write the service, controller, update all callers, and remove dead code.

- Write model improvements first (associations, constants, extracted methods)
- Write the service class
- Write the controller integration
- Update ALL callers to use the service directly — specs, import scripts, dev tools, event handlers, other plugins. Update test `before` blocks with any site settings the service's policy requires.
- Remove dead code: if a helper method is no longer called by any production code after extraction, delete it.
- When converting serializers to AMS, update ALL callers (controllers, services, publishers) and remove any wrapper methods that just delegated to the old serializer.

**Gate:** Present a summary of all files created, modified, and deleted. Wait for user acknowledgment before proceeding to Phase 4.

## Phase 4: Quality

Review the service against these structural rules. List every violation found.

- Service name should describe the core concept business, makes 5 suggestions to the user using AskUserQuestion, don't hesitate to namespace, eg: PluginName::BusinessSubject::Action
- Steps are simple with one concern each
- Step names describe domain behavior, not code (`revoke_previous_accepted_answer` not `destroy_old_record`). ALWAYS use Discourse core domain vocabulary. Ask "why is this happening?" not "what ActiveRecord method am I calling?"
- Descriptive param names: `post_id` not `id`, `channel_id` not `target`
- `context[:]` is a code smell. Verify a `model`, `options`, or step keyword argument cannot achieve the same result. Refactoring should almost always let you use a model instead.
- `transaction` wraps ONLY DB writes that must succeed or fail together. Side effects (webhooks, events, MessageBus) live outside.
- `lock` wraps ONLY steps vulnerable to concurrent modification. Side effects are idempotent and MUST live outside the lock.
- No `return if`/`return unless` at the top of step methods — use `only_if` wrappers. Guard clauses in `only_if` predicate methods use bare `return` (not `return false`).
- NEVER have an utility methods in a service, use model, step or a dedicated action instead
- Instead of manipulating data from the contract directly in various steps, attempt to extract logic on the contract itself
- NEVER rate limiting in the service — if necessary, it belongs in the controller via `before_action`
- NEVER use an optional model steps just to store a value for condition checks
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
- Serializers MUST inherit from `ApplicationSerializer` — never use plain classes with class-method `.serialize()` patterns
- Use `include_*?` methods for conditional attributes, not if/else hash building
- Extract nested serialization into separate serializer classes (e.g., topic data inside a card gets its own `CardTopicSerializer`)
- Use serializers directly at call sites: `MySerializer.new(object, root: false).as_json` — never hide them behind controller helper methods
- Pass pre-loaded data (e.g., batch-loaded assignments) through the serializer's options hash: `MySerializer.new(object, root: false, my_data:).as_json` accessed via `@options[:my_data]`
- ALWAYS use service_params and service_params.deep_merge(foo: bar) to pass params to the service from the controller

When in doubt AskUserQuestion.

**Audit loop:**
1. Produce the full audit table covering every rule above
2. Present the table to the user
3. If any FAIL verdicts exist:
   a. Fix every FAIL violation
   b. Return to step 1 — re-evaluate **all** rules, not just the ones you fixed (fixes can introduce new violations or invalidate previous PASS verdicts)
4. When the table is all PASS/NA, present it to the user for approval
5. Proceed to Phase 5 only after user approval

## Phase 5: Business logic

Trace every code path in the original implementation against the new service. List every bug found by criticality.

- Confirm no code path is dropped or subtly altered
- Verify side effects (DB writes, notifications, events, webhooks) fire under the same conditions and in the same order
- Check transactional boundaries: what was atomic before must remain atomic

**Audit loop:**
1. Produce the full audit table covering every rule above
2. Present the table to the user (including bugs from the prior implementation)
3. If any FAIL verdicts exist:
   a. Fix user-approved items
   b. Return to step 1 — re-trace **all** rules, not just the ones you fixed (fixes can introduce new regressions)
4. When the table is all PASS/NA, present it to the user for approval
5. Proceed to Phase 6 only after user approval

## Phase 6: Security

Review for security concerns. List every issue found by criticality.

- Access control: are policies enforced consistently regardless of caller?
- Category moderation: for category-scoped resources, never rely on `user.moderator?` / `guardian.is_moderator?` alone. Verify whether category moderators for the specific category should be allowed, and whether the actor can see or act on that exact resource via an existing guardian/policy method or `guardian.is_category_group_moderator?(category)` plus the relevant visibility check.
- MessageBus: secure audience applied to all publishes on secured channels?
- Data leakage: can non-privileged users infer existence of soft-deleted or private resources?

**Audit loop:**
1. Produce the full audit table covering every rule above
2. Present the table to the user
3. If any FAIL verdicts exist:
   a. Fix user-approved items
   b. Return to step 1 — re-review **all** rules, not just the ones you fixed
4. When the table is all PASS/NA, present it to the user for approval
5. Proceed to Phase 7 only after user approval

## Phase 7: Specs

**MANDATORY: Run this entire phase in a subagent.** Use the Agent tool to spawn a dedicated agent for writing and running specs. Pass it the service file path, the spec file path, and the full checklist below. Do NOT write specs in the main conversation.

### Reference sources

Two authoritative references govern how specs are written. Whenever you are unsure about an RSpec pattern, naming convention, matcher usage, or structural rule, **fetch the relevant section** before writing code:

1. **RSpec Style Guide** — https://rspec.rubystyle.guide
   Fetch this page and search for the keyword you need guidance on (e.g. "subject", "context", "let", "shared examples", "named subject", "aggregate_failures", "one expectation"). Use it as the definitive authority on RSpec idioms and style.

2. **Service documentation** — `docs/developer-guides/docs/03-code-internals/19-service-objects.md`, section **Testing**
   This is the definitive authority on testing Discourse services: structure, custom matchers, and conventions. Every spec must follow the patterns shown there.

### Checklist

- Test the contract in a separate `describe described_class::Contract, type: :model` block with shoulda matchers
- Use a `describe ".call"` block for the service execution
- Declare `subject(:result) { described_class.call(params:, **dependencies) }` as the first declaration in the `.call` block — the subject must be shared and parameterizable across contexts
- Declare setup data with `fab!`, params as `let(:params)`, dependencies as `let(:dependencies)` — order: subject, fab!, let, before
- One `context` per possible branching point, following the step order defined in the service
- Use the service-specific matchers for step failures: `fail_a_contract`, `fail_to_find_a_model(:name)`, `fail_a_policy(:name)`, `fail_with_an_invalid_model(:name)`, `fail_with_exception`, `fail_a_step(:name)`, `run_successfully`
- Do NOT re-test exhaustive contract validations in the `.call` block — the contract is tested above; the `.call` context only needs one example proving the step halts execution (e.g. one invalid value)
- The happy path context uses `run_successfully` and then tests side effects (DB changes, events, logs)
- Override `let` values in nested contexts to trigger each failure branch — NEVER duplicate the subject call
- Override `fab!` in nested contexts to change actors (e.g., `fab!(:acting_user, :admin)`) rather than overriding `let(:guardian)`
- ALWAYS use specific RSpec matchers (`change`, `eq`, `include`, `be_empty`, predicate matchers like `be_published`) — never bare `be` or vague assertions
- Context descriptions use "when …" / "with …" / "without …" phrasing
- Use `DiscourseEvent.track_events(:event_name) { result }` to test event triggers — NEVER manual `on`/`off`
- Use `let(:messages) { MessageBus.track_publish(channel) { result } }` as a lazy `let`
- Use fabricators for setup data, not raw `Model.create!`
- Use `:topic_with_op` fabricator when the topic needs an OP post for validations to pass
- Write model specs for any model callbacks introduced during the refactoring
- If an action is complex (many edge cases / branching), test it in isolation in its own spec file; the service spec only verifies it is called
- Follow the step order when writing contexts and methods

**Audit loop:**
1. Produce the full audit table covering every rule above
2. Present the table to the user
3. If any FAIL verdicts exist:
   a. Fix every FAIL violation
   b. Return to step 1 — re-evaluate **all** rules, not just the ones you fixed
4. When the table is all PASS/NA, present it to the user for approval
5. Run specs and lint. Fix failures and re-run until green
6. Proceed to Phase 8 only after user approval

## Phase 8: Finalization

Run the full plugin spec suite and any cross-plugin specs that touch the refactored code. Lint all changed files. Verify everything is green before presenting the completed work.
