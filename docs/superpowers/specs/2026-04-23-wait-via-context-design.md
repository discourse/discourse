# Wait via `put_execution_to_wait` runtime context API

## Goal

Replace the `Executor::WaitForResume` value object and `Executor::WaitRequested`-driven node contract with an n8n-style runtime capability: the node pauses its execution by calling `exec_ctx.put_execution_to_wait(waiting_until)` on its `NodeExecutionContext`. The executor reads a flag on the context after `execute` returns and branches into the pause path. The per-wait-type `waiting_config` blob is dropped; wait behavior is derived from the paused node's configuration at resume/read time.

This matches n8n's `context.putExecutionToWait(waitTill)` in `packages/core/src/execution-engine/node-execution-context/base-execute-context.ts:107-112` and the consuming engine checks in `workflow-execute.ts` around lines 1797, 1849, 1978, 2428, 2472.

## Non-goals

- Changing the resume trigger paths (webhook URL shape, form URL shape, expiry job cadence).
- Changing how `resume_token` is generated.
- Changing the expression resolver.

## Current state (as of 2026-04-23)

- `Nodes::Wait::V1#execute` and `Nodes::Form::V1#execute` return `Executor::WaitForResume.new(waiting_until:, waiting_config:)`.
- `Executor#execute_node` checks `result.is_a?(WaitForResume)` and raises `Executor::WaitRequested`.
- `Executor#begin_wait!` persists `Execution#waiting_until` and `Execution#waiting_config` (jsonb).
- `Execution#waiting_config` holds a mix of:
  - discriminator: `wait_type` (`form_trigger`/`form`/`webhook`/`timer`)
  - execution-scoped: `resume_token`, `timeout_action`, `timeout_response_items`
  - node-config echoes: `http_method`, `response_mode`, `response_code`, `webhook_suffix`, `form_title`, `form_description`, `form_fields`, `wait_amount`, `wait_unit`
  - executor bookkeeping: `node_contexts`, `step_position`
- Readers scattered across `app/services/discourse_workflows/webhook/receive.rb`, `form/show.rb`, `form/resume.rb`, `form/submit.rb`, `execution/expire_waiting.rb`, and `app/jobs/regular/discourse_workflows/resume_waiting_execution.rb`.

## Target design

### Node contract

```ruby
# Nodes::Wait::V1#execute
def execute(exec_ctx)
  # validation / computation of waiting_until...
  exec_ctx.put_execution_to_wait(waiting_until)
  [exec_ctx.input_items]
end
```

`put_execution_to_wait` takes exactly one positional argument (a Time, or `nil` to request the ceiling).

### `NodeExecutionContext`

```ruby
attr_reader :waiting_until

def put_execution_to_wait(waiting_until = nil)
  @waiting = true
  @waiting_until = waiting_until
end

def waiting?
  @waiting == true
end
```

Default `@waiting = false` in `initialize`. `waiting_until = nil` means "no explicit deadline; let the executor apply its ceiling."

### Executor flow

```ruby
# Executor#execute_node (replacing the result.is_a?(WaitForResume) branch)
result = node_type_class.new(configuration: node.configuration).execute(exec_ctx)

if exec_ctx.waiting?
  step.mark_waiting!
  @waiting_node = node
  @waiting_step = step
  raise WaitRequested, exec_ctx.waiting_until
end
# ... normal routing unchanged
```

`Executor::WaitRequested` becomes a private control-flow signal carrying only the requested `Time` (or nil):

```ruby
class WaitRequested < StandardError
  attr_reader :waiting_until
  def initialize(waiting_until)
    @waiting_until = waiting_until
    super("Wait requested")
  end
end
```

`Executor::WaitForResume` is deleted (file and class).

`Executor#begin_wait!` inlines the ceiling calculation:

```ruby
def begin_wait!(waiting_until)
  now = Time.current
  ceiling = now + MAX_WAIT_DURATION_SECONDS
  resolved = waiting_until.blank? ? ceiling : [waiting_until, ceiling].min

  execution = @store.pause_waiting_execution!(node: @waiting_node, waiting_until: resolved, steps: @steps)
  duration = [resolved - now, 0].max
  Jobs.enqueue_in(duration, Jobs::DiscourseWorkflows::ResumeWaitingExecution, execution_id: execution.id)
  execution
rescue => e
  @store.fail!(error: e, steps: @steps)
end
```

`pause_waiting_execution!` loses its `waiting_config:` keyword.

### Persistence

Drop `executions.waiting_config` entirely. Add:

- `executions.resume_token` (string, indexed) — execution-scoped identifier for webhook/form matching
- `executions.timeout_action` (string, nullable, values: `"fail"` or nil) — nil means "resume with input items"

Today's `node_contexts` and `step_position` (bookkeeping the executor needs on resume) move into `execution_data.context_data` under reserved keys `__node_contexts` and `__step_position`, written/read by `ExecutionStore#save!` and `restore_from!`.

### Reader rewrites

All readers that dig into `waiting_config` move to either the new column or the paused node's configuration, loaded through the workflow (`execution.workflow.find_node(execution.waiting_node_id)`).

| File | Before | After |
|---|---|---|
| `execution.rb` `waiting_with_type` scope | filter on `waiting_config->>'wait_type'` | remove scope; callers already have `resume_token` to narrow to one row and then check node type in-Ruby |
| `execution.rb` `by_resume_token` scope | filter on `waiting_config->>'resume_token'` | `where(resume_token: token, status: :waiting)` |
| `execution.rb#fail_with_timeout!` | clears `waiting_config: {}` | drop that line; clear `resume_token: nil`, `timeout_action: nil` |
| `executor/execution_store.rb#create_waiting_for_trigger` | writes `waiting_config` with `wait_type`, `resume_token`, `timeout_action` | writes `resume_token: ..., timeout_action: "fail"` columns |
| `executor/execution_store.rb#pause_waiting_execution!` | merges `waiting_config` | drops `waiting_config:` kw; still writes `waiting_node_id`, `waiting_until`; `resume_token` was already set at execution creation so stays |
| `executor/execution_store.rb#clear_waiting_execution!` | clears `waiting_config: {}` | drop that line (column gone) |
| `executor/execution_store.rb#restore_from!` | reads `execution.waiting_config['node_contexts']` | reads `execution_data.context_data['__node_contexts']` |
| `webhook/receive.rb#fetch_waiting_execution` | `waiting_config->>'resume_token'`, `waiting_config->>'webhook_suffix'` | `execution.resume_token` column; webhook_suffix from paused Wait node's `configuration["webhook_suffix"]` |
| `webhook/receive.rb#validate_waiting_http_method` | `waiting_config["http_method"]` | paused Wait node's `configuration["http_method"]` |
| `webhook/receive.rb#async_resume?`, `resume_execution_synchronously` | `waiting_config["response_mode"]`, `waiting_config["response_code"]` | paused Wait node's `configuration["response_mode"]`, `configuration["response_code"]` |
| `form/show.rb#fetch_waiting_execution` | by_resume_token + `wait_type='form'` | by_resume_token + in-Ruby check `waiting_node.type == "action:form"` |
| `form/show.rb#build_form_data_from_execution` | reads pre-resolved `form_title`/`description`/`fields` from `waiting_config` | loads `execution_data`, resolves expressions against it using `ExpressionResolver`, reads title/description/fields from paused Form node's config |
| `form/resume.rb#fetch_execution` | by_resume_token + `wait_type='form'` | by_resume_token + in-Ruby check `waiting_node.type == "action:form"` |
| `form/submit.rb#fetch_trigger_execution` | `waiting_config->>'resume_token' = ?` + `wait_type='form_trigger'` | `where(resume_token:, workflow:)` + check `waiting_node_id == trigger_node["id"]` |
| `execution/expire_waiting.rb#expire_execution` | reads `waiting_config["timeout_action"]`, `waiting_config["timeout_response_items"]` | reads `execution.timeout_action` column; drop `timeout_response_items` (no writer ever set it) |
| `resume_waiting_execution.rb` job | same | same rewrite as expire |

### Resolving form_title/description/fields at read time

`form/show.rb#build_form_data_from_execution` becomes:

```ruby
def build_form_data_from_execution(waiting_execution:, workflow:, form_node:, params:, guardian:)
  resume_token = waiting_execution.resume_token
  context_data = waiting_execution.execution_data&.context_data || {}

  exec_context = {
    "__execution" => {
      "id" => waiting_execution.id,
      "workflow_id" => workflow.id,
      "workflow_name" => workflow.name,
      "resume_url" => "#{Discourse.base_url}/workflows/webhooks/#{waiting_execution.id}?token=#{resume_token}",
    },
  }.merge(context_data)

  config = form_node["configuration"] || {}

  {
    uuid: params.uuid,
    form_title: ExpressionResolver.resolve(config["form_title"], context: exec_context, user: guardian.user),
    form_description: ExpressionResolver.resolve(config["form_description"], context: exec_context, user: guardian.user),
    form_fields: Workflow.resolve_field_keys(config["form_fields"] || []),
    response_mode: "on_received",
    has_downstream_form: workflow.node_has_reachable_downstream_of_type?(form_node["id"], "action:form"),
    resume_token: resume_token,
  }
end
```

Field values already pre-resolved elsewhere in `execution_data.context_data` remain available through the `$json`/`$vars`/etc. exposed by the resolver.

## Migration

Two-step migration to keep the deploy safe:

**Pre-migrate** (`db/migrate`):
- `add_column :discourse_workflows_executions, :resume_token, :string`
- `add_column :discourse_workflows_executions, :timeout_action, :string`
- `add_index :discourse_workflows_executions, :resume_token, where: "resume_token IS NOT NULL"`
- Backfill for `status = waiting`:
  - `UPDATE ... SET resume_token = waiting_config->>'resume_token', timeout_action = waiting_config->>'timeout_action' WHERE status = 4`
- For in-flight waits, copy `waiting_config->'node_contexts'` and `waiting_config->>'step_position'` into `execution_data.data`'s context as `__node_contexts` / `__step_position` via a small Ruby step in the migration.

**Post-migrate** (`db/post_migrate`):
- `remove_column :discourse_workflows_executions, :waiting_config`

## Test impact

- `spec/lib/discourse_workflows/executor_wait_spec.rb`: assertions on `waiting_node_id` and `waiting_until` remain; `waiting_config` assertions removed.
- `spec/lib/discourse_workflows/nodes/wait/v1_spec.rb`: build an `exec_ctx`, call `.execute`, then assert `exec_ctx.waiting?` and `exec_ctx.waiting_until`. Delete the `expect(...).to be_a(WaitForResume)` lines.
- `spec/lib/discourse_workflows/nodes/form_spec.rb`: same rewrite as wait/v1.
- `spec/requests/discourse_workflows/forms_controller_spec.rb`: fixtures that stub `waiting_config` rebuild a real waiting execution (pause a workflow) instead.
- `spec/services/discourse_workflows/form/show_spec.rb`, `form/submit_spec.rb`, `form/resume_spec.rb`: same.
- `spec/services/discourse_workflows/execution/expire_waiting_spec.rb`: set `timeout_action` column instead of seeding `waiting_config`.
- New spec for `NodeExecutionContext#put_execution_to_wait` in `spec/lib/discourse_workflows/executor/node_execution_context_spec.rb`.

## Affected files

**Edit**
- `lib/discourse_workflows/executor.rb`
- `lib/discourse_workflows/executor/execution_store.rb`
- `lib/discourse_workflows/executor/node_execution_context.rb`
- `lib/discourse_workflows/nodes/wait/v1.rb`
- `lib/discourse_workflows/nodes/form/v1.rb`
- `app/models/discourse_workflows/execution.rb`
- `app/jobs/regular/discourse_workflows/resume_waiting_execution.rb`
- `app/services/discourse_workflows/webhook/receive.rb`
- `app/services/discourse_workflows/form/show.rb`
- `app/services/discourse_workflows/form/resume.rb`
- `app/services/discourse_workflows/form/submit.rb`
- `app/services/discourse_workflows/execution/expire_waiting.rb`

**Delete**
- `lib/discourse_workflows/executor/wait_for_resume.rb`

**New migrations**
- `db/migrate/YYYYMMDDHHMMSS_add_resume_fields_to_executions.rb` (add columns + backfill)
- `db/post_migrate/YYYYMMDDHHMMSS_drop_waiting_config_from_executions.rb`

## Risks

- **Read-time expression resolution** in form/show depends on `execution_data.context_data` containing the right `$json`/`$vars`. Current behavior pre-resolves at pause, so any missing piece of context is a silent behavior change. Mitigation: exercise the Form resume flow end-to-end in a system spec before merging.
- **In-flight waits during deploy**: the backfill copies `resume_token` and `timeout_action` into columns before the post-migrate drops `waiting_config`. If a node_context/step_position key is missed in the backfill, a mid-deploy resume would lose executor bookkeeping. Mitigation: deploy the pre-migrate first, let it settle, then ship the code changes + post-migrate as one unit.
- **`timeout_response_items`** is read by `expire_waiting` and the job but has no production writer — only test fixtures set it (`spec/services/discourse_workflows/execution/expire_waiting_spec.rb` seeds it to cover the branch). Dropping the branch removes a capability that was wired but never triggered in product code. Replace those test fixtures with the `timeout_action: "fail"` shape covered by the new column; the "resume with input items" branch continues via the default `timeout_action: nil`.
