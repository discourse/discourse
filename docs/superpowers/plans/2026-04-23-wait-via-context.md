# Wait via `put_execution_to_wait` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `Executor::WaitForResume` value-object contract with a `put_execution_to_wait` method on `NodeExecutionContext`, and drop the `executions.waiting_config` jsonb column in favor of deriving wait behavior from the paused node plus two new first-class columns (`resume_token`, `timeout_action`).

**Architecture:** Two layers change together.
1. **Node contract:** wait-capable nodes (Wait v1, Form v1) call `exec_ctx.put_execution_to_wait(waiting_until)` and return passthrough items. The executor checks `exec_ctx.waiting?` after `execute` returns and branches to the pause path before routing output.
2. **Persistence:** `waiting_config` jsonb → promoted columns + node-config derivation. In-flight waits migrated via a Ruby-script `db/migrate`, with the `waiting_config` column dropped in `db/post_migrate`.

**Tech Stack:** Ruby 3.3 / Rails 8.x, RSpec + FactoryBot, Discourse `Service::Base` pattern, PostgreSQL jsonb. No JS changes.

**Spec:** `docs/superpowers/specs/2026-04-23-wait-via-context-design.md`

---

## Task 1: Introduce `put_execution_to_wait` on NodeExecutionContext

Add the new runtime capability. Nothing reads the flag yet; this task is purely additive.

**Files:**
- Modify: `plugins/discourse-workflows/lib/discourse_workflows/executor/node_execution_context.rb`
- Test: `plugins/discourse-workflows/spec/lib/discourse_workflows/executor/node_execution_context_spec.rb`

- [ ] **Step 1: Write the failing test**

Append to the `describe` block at the top of `spec/lib/discourse_workflows/executor/node_execution_context_spec.rb`:

```ruby
  describe "#put_execution_to_wait" do
    it "defaults to not waiting" do
      ctx = described_class.new(input_items: [], resolver: nil)
      expect(ctx).not_to be_waiting
      expect(ctx.waiting_until).to be_nil
    end

    it "flags the context as waiting with the given deadline" do
      ctx = described_class.new(input_items: [], resolver: nil)
      deadline = 2.hours.from_now

      ctx.put_execution_to_wait(deadline)

      expect(ctx).to be_waiting
      expect(ctx.waiting_until).to eq(deadline)
    end

    it "accepts a nil deadline to request the executor ceiling" do
      ctx = described_class.new(input_items: [], resolver: nil)

      ctx.put_execution_to_wait(nil)

      expect(ctx).to be_waiting
      expect(ctx.waiting_until).to be_nil
    end
  end
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
bin/rspec plugins/discourse-workflows/spec/lib/discourse_workflows/executor/node_execution_context_spec.rb -e "#put_execution_to_wait"
```

Expected: 3 failures with `NoMethodError: undefined method 'put_execution_to_wait'`.

- [ ] **Step 3: Add the API to NodeExecutionContext**

Edit `lib/discourse_workflows/executor/node_execution_context.rb`:

- Add `:waiting_until` to the `attr_reader` list (keep the existing list intact).
- In `initialize`, set `@waiting = false` and `@waiting_until = nil` just after the existing `@log = StepLog.new` line.
- Add these two methods right above `private`:

```ruby
      def put_execution_to_wait(waiting_until = nil)
        @waiting = true
        @waiting_until = waiting_until
      end

      def waiting?
        @waiting == true
      end
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
bin/rspec plugins/discourse-workflows/spec/lib/discourse_workflows/executor/node_execution_context_spec.rb
```

Expected: all examples pass.

- [ ] **Step 5: Lint**

```bash
bin/lint plugins/discourse-workflows/lib/discourse_workflows/executor/node_execution_context.rb plugins/discourse-workflows/spec/lib/discourse_workflows/executor/node_execution_context_spec.rb
```

Expected: no offenses.

- [ ] **Step 6: Commit**

```bash
git add plugins/discourse-workflows/lib/discourse_workflows/executor/node_execution_context.rb plugins/discourse-workflows/spec/lib/discourse_workflows/executor/node_execution_context_spec.rb
git commit -m "DEV: Add put_execution_to_wait API to NodeExecutionContext"
```

---

## Task 2: Executor consumes the context waiting flag (dual-path)

Make `Executor#execute_node` honor `exec_ctx.waiting?` in addition to the existing `result.is_a?(WaitForResume)` branch. Existing nodes continue to work unchanged; new nodes can now signal via context.

**Files:**
- Modify: `plugins/discourse-workflows/lib/discourse_workflows/executor.rb`
- Test: `plugins/discourse-workflows/spec/lib/discourse_workflows/executor_wait_spec.rb`

- [ ] **Step 1: Write the failing test**

Add a new spec at the bottom of the outer `RSpec.describe DiscourseWorkflows::Executor do` block in `spec/lib/discourse_workflows/executor_wait_spec.rb`, inside the existing `describe "pause on wait request"` block:

```ruby
    it "pauses when a node signals via exec_ctx.put_execution_to_wait" do
      stub_const("Nodes::CtxWaitV1", Class.new(DiscourseWorkflows::NodeType) do
        def self.identifier; "flow:ctx_wait"; end
        def self.waits_for_resume?; true; end
        def self.property_schema; {}; end
        def execute(exec_ctx)
          exec_ctx.put_execution_to_wait(1.hour.from_now)
          [exec_ctx.input_items]
        end
      end)
      DiscourseWorkflows::Registry.register(Nodes::CtxWaitV1)

      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "wait-1", "flow:ctx_wait"
          g.chain "trigger-1", "wait-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

      freeze_time do
        execution = described_class.new(workflow, "trigger-1", {}).run

        expect(execution).to have_attributes(
          status: "waiting",
          waiting_node_id: "wait-1",
          waiting_until: 1.hour.from_now,
        )
      end
    ensure
      DiscourseWorkflows::Registry.unregister("flow:ctx_wait") if defined?(Nodes::CtxWaitV1)
    end
```

If `Registry.unregister` does not exist, inspect `lib/discourse_workflows/registry.rb` and use whatever teardown mechanism is available (e.g. reloading the default set). If no teardown exists at all, add one in this task. Running the existing tests after your change will reveal whether global state leaks.

- [ ] **Step 2: Run the test to verify it fails**

```bash
bin/rspec plugins/discourse-workflows/spec/lib/discourse_workflows/executor_wait_spec.rb -e "exec_ctx.put_execution_to_wait"
```

Expected: fail — the executor currently ignores the flag; the execution finishes as `success` without pausing.

- [ ] **Step 3: Teach the executor to read the context flag**

In `lib/discourse_workflows/executor.rb`, edit `execute_node`. Replace the existing wait branch (the `if result.is_a?(WaitForResume)` block) so the method also handles `exec_ctx.waiting?`:

```ruby
        result = node_type_class.new(configuration: node.configuration).execute(exec_ctx)

        if exec_ctx.waiting?
          step.mark_waiting!
          @waiting_node = node
          @waiting_step = step
          raise WaitRequested, WaitForResume.new(waiting_until: exec_ctx.waiting_until)
        end

        if result.is_a?(WaitForResume)
          step.mark_waiting!
          @waiting_node = node
          @waiting_step = step
          raise WaitRequested, result
        end
```

Both branches remain; subsequent tasks will remove the legacy one. Use `WaitForResume.new(waiting_until: ...)` with no `waiting_config` because context-signaled waits never carry one.

- [ ] **Step 4: Run the wait specs to verify everything still passes**

```bash
bin/rspec plugins/discourse-workflows/spec/lib/discourse_workflows/executor_wait_spec.rb plugins/discourse-workflows/spec/lib/discourse_workflows/nodes/wait/v1_spec.rb plugins/discourse-workflows/spec/lib/discourse_workflows/nodes/form_spec.rb
```

Expected: all examples pass (including the new one).

- [ ] **Step 5: Lint**

```bash
bin/lint plugins/discourse-workflows/lib/discourse_workflows/executor.rb plugins/discourse-workflows/spec/lib/discourse_workflows/executor_wait_spec.rb
```

Expected: no offenses.

- [ ] **Step 6: Commit**

```bash
git add plugins/discourse-workflows/lib/discourse_workflows/executor.rb plugins/discourse-workflows/spec/lib/discourse_workflows/executor_wait_spec.rb
git commit -m "DEV: Honor exec_ctx.put_execution_to_wait in workflow executor"
```

---

## Task 3: Wait v1 switches to the context API

Convert `Nodes::Wait::V1#execute` to call `exec_ctx.put_execution_to_wait(...)` and return passthrough items. The `waiting_config` payload currently produced by this node disappears because all its values (`wait_type`, `resume_token`, `http_method`, `response_mode`, `response_code`, `webhook_suffix`, `wait_amount`, `wait_unit`) are derivable from the node's configuration at read time. Readers are rewritten in Tasks 9–13.

**Files:**
- Modify: `plugins/discourse-workflows/lib/discourse_workflows/nodes/wait/v1.rb`
- Test: `plugins/discourse-workflows/spec/lib/discourse_workflows/nodes/wait/v1_spec.rb`

- [ ] **Step 1: Rewrite the wait node spec**

Overwrite `spec/lib/discourse_workflows/nodes/wait/v1_spec.rb` with:

```ruby
# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Wait::V1 do
  def build_exec_ctx(configuration, resume_token: nil)
    DiscourseWorkflows::Executor::NodeExecutionContext.new(
      input_items: [{ "json" => {} }],
      configuration: configuration,
      property_schema: described_class.property_schema,
      node_context: {},
      resolver: DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }),
      resume_token: resume_token,
    )
  end

  describe "#execute" do
    it "requests a timer wait for interval mode" do
      config = { "resume" => "time_interval", "wait_amount" => 2, "wait_unit" => "hours" }
      exec_ctx = build_exec_ctx(config)

      freeze_time do
        result = described_class.new(configuration: config).execute(exec_ctx)

        expect(exec_ctx).to be_waiting
        expect(exec_ctx.waiting_until).to eq(2.hours.from_now)
        expect(result).to eq([exec_ctx.input_items])
      end
    end

    it "requests an indefinite webhook wait when limit_wait_time is false" do
      config = { "resume" => "webhook" }
      exec_ctx = build_exec_ctx(config, resume_token: "tok-abc")

      described_class.new(configuration: config).execute(exec_ctx)

      expect(exec_ctx).to be_waiting
      expect(exec_ctx.waiting_until).to be_nil
    end

    it "requests a bounded webhook wait when limit_wait_time is true" do
      config = {
        "resume" => "webhook",
        "limit_wait_time" => true,
        "timeout_amount" => 3,
        "timeout_unit" => "hours",
      }
      exec_ctx = build_exec_ctx(config, resume_token: "tok-abc")

      freeze_time do
        described_class.new(configuration: config).execute(exec_ctx)

        expect(exec_ctx).to be_waiting
        expect(exec_ctx.waiting_until).to eq(3.hours.from_now)
      end
    end

    it "raises on a non-positive wait amount" do
      config = { "resume" => "time_interval", "wait_amount" => 0, "wait_unit" => "hours" }
      exec_ctx = build_exec_ctx(config)

      expect { described_class.new(configuration: config).execute(exec_ctx) }.to raise_error(
        ArgumentError,
        /Wait amount/,
      )
    end

    it "raises on an invalid wait unit" do
      config = { "resume" => "time_interval", "wait_amount" => 1, "wait_unit" => "weeks" }
      exec_ctx = build_exec_ctx(config)

      expect { described_class.new(configuration: config).execute(exec_ctx) }.to raise_error(
        ArgumentError,
        /Invalid wait unit/,
      )
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
bin/rspec plugins/discourse-workflows/spec/lib/discourse_workflows/nodes/wait/v1_spec.rb
```

Expected: failures — the node still returns a `WaitForResume` object; `exec_ctx` is not flagged as waiting.

- [ ] **Step 3: Rewrite `execute` on the Wait node**

Replace the entire `execute` method in `lib/discourse_workflows/nodes/wait/v1.rb` (currently at lines 103-155) with:

```ruby
        def execute(exec_ctx)
          resume_mode = @configuration.fetch("resume")

          if resume_mode == "webhook"
            waiting_until = webhook_waiting_until
          else
            amount = @configuration.fetch("wait_amount") { 1 }.to_i
            unit = @configuration.fetch("wait_unit") { "hours" }

            raise ArgumentError, "Wait amount must be greater than 0" if amount <= 0
            raise ArgumentError, "Invalid wait unit: #{unit}" if WAIT_UNITS.exclude?(unit)

            waiting_until = amount.public_send(unit).from_now
          end

          exec_ctx.put_execution_to_wait(waiting_until)
          [exec_ctx.input_items]
        end

        private

        def webhook_waiting_until
          return nil unless @configuration["limit_wait_time"]

          timeout_amount = @configuration["timeout_amount"].presence&.to_i
          timeout_unit = @configuration["timeout_unit"].presence || "hours"

          raise ArgumentError, "Invalid timeout unit: #{timeout_unit}" if WAIT_UNITS.exclude?(timeout_unit)
          if timeout_amount && timeout_amount <= 0
            raise ArgumentError, "Timeout amount must be greater than 0"
          end

          timeout_amount&.public_send(timeout_unit)&.from_now
        end
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
bin/rspec plugins/discourse-workflows/spec/lib/discourse_workflows/nodes/wait/v1_spec.rb plugins/discourse-workflows/spec/lib/discourse_workflows/executor_wait_spec.rb
```

Expected: all examples pass. The `executor_wait_spec` still passes because the executor now honors either signal.

- [ ] **Step 5: Lint**

```bash
bin/lint plugins/discourse-workflows/lib/discourse_workflows/nodes/wait/v1.rb plugins/discourse-workflows/spec/lib/discourse_workflows/nodes/wait/v1_spec.rb
```

- [ ] **Step 6: Commit**

```bash
git add plugins/discourse-workflows/lib/discourse_workflows/nodes/wait/v1.rb plugins/discourse-workflows/spec/lib/discourse_workflows/nodes/wait/v1_spec.rb
git commit -m "DEV: Port Wait v1 node to put_execution_to_wait API"
```

---

## Task 4: Form v1 switches to the context API

Same shape as Task 3. Form v1 was writing the pre-resolved `form_title`/`form_description`/`form_fields` into `waiting_config`; after this task, it no longer persists that echo because form/show will resolve at read time (Task 10).

**Files:**
- Modify: `plugins/discourse-workflows/lib/discourse_workflows/nodes/form/v1.rb`
- Test: `plugins/discourse-workflows/spec/lib/discourse_workflows/nodes/form_spec.rb`

- [ ] **Step 1: Rewrite the relevant block of the form node spec**

In `spec/lib/discourse_workflows/nodes/form_spec.rb`, find the example that asserts `expect(wait).to be_a(DiscourseWorkflows::Executor::WaitForResume)` (around line 28). Replace that `describe`/`it` with:

```ruby
    it "signals a wait via exec_ctx for non-completion forms" do
      config = {
        "form_title" => "Approval",
        "form_description" => "Please approve",
        "form_fields" => [{ "field_label" => "Reason", "field_type" => "text" }],
      }
      exec_ctx = build_exec_ctx(config, resume_token: "tok-xyz")
      allow(MessageBus).to receive(:publish)

      result = described_class.new(configuration: config).execute(exec_ctx)

      expect(exec_ctx).to be_waiting
      expect(exec_ctx.waiting_until).to be_nil
      expect(result).to eq([exec_ctx.input_items])
    end
```

If the spec uses a `build_exec_ctx` helper already, reuse it; otherwise copy the helper from `spec/lib/discourse_workflows/nodes/wait/v1_spec.rb`.

- [ ] **Step 2: Run the test to verify it fails**

```bash
bin/rspec plugins/discourse-workflows/spec/lib/discourse_workflows/nodes/form_spec.rb
```

Expected: failure — still returns `WaitForResume`.

- [ ] **Step 3: Rewrite the wait branch of Form v1**

In `lib/discourse_workflows/nodes/form/v1.rb`, replace the `Executor::WaitForResume.new(...)` call at the bottom of `execute` with:

```ruby
          channel =
            DiscourseWorkflows::Executor.form_channel(exec_ctx.execution_id, exec_ctx.resume_token)
          MessageBus.publish(channel, { status: "waiting_for_form" })

          exec_ctx.put_execution_to_wait(nil)
          [exec_ctx.input_items]
```

The completion branch (the `if page_type == "completion"` block) is unchanged — completion forms don't wait, they just set flow context and return items.

- [ ] **Step 4: Run the test to verify it passes**

```bash
bin/rspec plugins/discourse-workflows/spec/lib/discourse_workflows/nodes/form_spec.rb plugins/discourse-workflows/spec/lib/discourse_workflows/executor_wait_spec.rb
```

Expected: all examples pass.

- [ ] **Step 5: Lint**

```bash
bin/lint plugins/discourse-workflows/lib/discourse_workflows/nodes/form/v1.rb plugins/discourse-workflows/spec/lib/discourse_workflows/nodes/form_spec.rb
```

- [ ] **Step 6: Commit**

```bash
git add plugins/discourse-workflows/lib/discourse_workflows/nodes/form/v1.rb plugins/discourse-workflows/spec/lib/discourse_workflows/nodes/form_spec.rb
git commit -m "DEV: Port Form v1 node to put_execution_to_wait API"
```

---

## Task 5: Remove the legacy `Executor::WaitForResume` branch

Delete `WaitForResume` and simplify `WaitRequested` to carry only the requested `Time`. The ceiling math moves into `Executor#begin_wait!`.

**Files:**
- Modify: `plugins/discourse-workflows/lib/discourse_workflows/executor.rb`
- Delete: `plugins/discourse-workflows/lib/discourse_workflows/executor/wait_for_resume.rb`

- [ ] **Step 1: Delete the legacy branch and file**

In `lib/discourse_workflows/executor.rb`:

Replace the `class WaitRequested` definition (currently at lines 10–17) with:

```ruby
    class WaitRequested < StandardError
      attr_reader :waiting_until

      def initialize(waiting_until)
        @waiting_until = waiting_until
        super("Wait requested")
      end
    end
```

In `execute_node`, delete the second `if result.is_a?(WaitForResume)` branch added in Task 2 so that only the `exec_ctx.waiting?` branch remains:

```ruby
        result = node_type_class.new(configuration: node.configuration).execute(exec_ctx)

        if exec_ctx.waiting?
          step.mark_waiting!
          @waiting_node = node
          @waiting_step = step
          raise WaitRequested, exec_ctx.waiting_until
        end
```

Update `begin_wait!` to inline the ceiling calculation — replace the method body with:

```ruby
    def begin_wait!(waiting_until)
      now = Time.current
      ceiling = now + MAX_WAIT_DURATION_SECONDS
      resolved = waiting_until.blank? ? ceiling : [waiting_until, ceiling].min

      execution =
        @store.pause_waiting_execution!(
          node: @waiting_node,
          waiting_until: resolved,
          waiting_config: {},
          steps: @steps,
        )

      duration = [resolved - now, 0].max
      Jobs.enqueue_in(
        duration,
        Jobs::DiscourseWorkflows::ResumeWaitingExecution,
        execution_id: @store.execution.id,
      )

      execution
    rescue => e
      @store.fail!(error: e, steps: @steps)
    end
```

`pause_waiting_execution!` still takes a `waiting_config:` keyword in this task; Task 7 drops it. Passing `waiting_config: {}` for now keeps the existing signature intact.

Update the `rescue WaitRequested => e` in `execute_flow` (around line 102) to pass `e.waiting_until` instead of `e.wait_request`:

```ruby
    rescue WaitRequested => e
      begin_wait!(e.waiting_until)
```

Delete the file:

```bash
rm plugins/discourse-workflows/lib/discourse_workflows/executor/wait_for_resume.rb
```

- [ ] **Step 2: Run the wait specs**

```bash
bin/rspec plugins/discourse-workflows/spec/lib/discourse_workflows/executor_wait_spec.rb plugins/discourse-workflows/spec/lib/discourse_workflows/nodes/wait/v1_spec.rb plugins/discourse-workflows/spec/lib/discourse_workflows/nodes/form_spec.rb
```

Expected: pass. The cross-over test added in Task 2 (using the stub ctx-wait node) still passes because we kept the `exec_ctx.waiting?` branch.

- [ ] **Step 3: Remove the stub test added in Task 2**

Now that the real wait/form nodes exercise the same path, the stub test from Task 2 step 1 is redundant. Remove the `it "pauses when a node signals via exec_ctx.put_execution_to_wait"` example from `spec/lib/discourse_workflows/executor_wait_spec.rb`.

- [ ] **Step 4: Run the wait specs again**

```bash
bin/rspec plugins/discourse-workflows/spec/lib/discourse_workflows/executor_wait_spec.rb
```

Expected: pass with the original four examples only.

- [ ] **Step 5: Lint**

```bash
bin/lint plugins/discourse-workflows/lib/discourse_workflows/executor.rb plugins/discourse-workflows/spec/lib/discourse_workflows/executor_wait_spec.rb
```

- [ ] **Step 6: Commit**

```bash
git add -A plugins/discourse-workflows/lib/discourse_workflows/executor.rb plugins/discourse-workflows/lib/discourse_workflows/executor/wait_for_resume.rb plugins/discourse-workflows/spec/lib/discourse_workflows/executor_wait_spec.rb
git commit -m "DEV: Drop Executor::WaitForResume value object"
```

---

## Task 6: Add `resume_token` and `timeout_action` columns

Pre-migrate that adds the new columns and backfills in-flight waits. Also moves `node_contexts` from `waiting_config` into `execution_data.data` JSON so Task 7 can read it from its new home. `waiting_config` stays in place until Task 14.

**Files:**
- Create: `plugins/discourse-workflows/db/migrate/YYYYMMDDHHMMSS_add_resume_fields_to_workflow_executions.rb` (use the current timestamp from `date +%Y%m%d%H%M%S`)

- [ ] **Step 1: Generate the migration timestamp**

Run:

```bash
TS=$(date +%Y%m%d%H%M%S); echo "$TS"
```

Note the value; you'll substitute it for `YYYYMMDDHHMMSS` below.

- [ ] **Step 2: Create the migration file**

Create `plugins/discourse-workflows/db/migrate/<TS>_add_resume_fields_to_workflow_executions.rb`:

```ruby
# frozen_string_literal: true

class AddResumeFieldsToWorkflowExecutions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    add_column :discourse_workflows_executions, :resume_token, :string
    add_column :discourse_workflows_executions, :timeout_action, :string

    add_index :discourse_workflows_executions,
              :resume_token,
              where: "resume_token IS NOT NULL",
              algorithm: :concurrently,
              if_not_exists: true

    execute <<~SQL
      UPDATE discourse_workflows_executions
      SET resume_token = waiting_config->>'resume_token',
          timeout_action = waiting_config->>'timeout_action'
      WHERE status = 4
        AND waiting_config IS NOT NULL
        AND waiting_config != '{}'::jsonb
    SQL

    execute <<~SQL
      UPDATE discourse_workflows_execution_data ed
      SET data = jsonb_set(
        COALESCE(ed.data::jsonb, '{}'::jsonb),
        '{node_contexts}',
        COALESCE(e.waiting_config->'node_contexts', '{}'::jsonb),
        true
      )::text
      FROM discourse_workflows_executions e
      WHERE ed.execution_id = e.id
        AND e.status = 4
        AND e.waiting_config ? 'node_contexts'
    SQL
  end

  def down
    remove_index :discourse_workflows_executions, :resume_token, if_exists: true
    remove_column :discourse_workflows_executions, :resume_token
    remove_column :discourse_workflows_executions, :timeout_action
  end
end
```

- [ ] **Step 3: Run the migration**

```bash
bin/rake db:migrate
bin/rake db:migrate RAILS_ENV=test
```

Expected: migration runs cleanly, adds both columns and the index.

- [ ] **Step 4: Verify the schema**

```bash
bin/rails runner 'puts DiscourseWorkflows::Execution.column_names.grep(/resume_token|timeout_action/)'
```

Expected output:

```
resume_token
timeout_action
```

- [ ] **Step 5: Commit**

```bash
git add plugins/discourse-workflows/db/migrate/
git commit -m "DEV: Add resume_token and timeout_action columns to workflow executions"
```

---

## Task 7: ExecutionStore writes to the new locations

`ExecutionStore#pause_waiting_execution!` stops writing `waiting_config` (except to clear/overwrite whatever is there), writes `resume_token` to the column via `@execution_context.resume_token`, persists `node_contexts` under `execution_data.data->'node_contexts'` via `save!`. `restore_from!` reads `node_contexts` from `execution_data.node_contexts`. `clear_waiting_execution!` also nils the new columns. `create_waiting_for_trigger` is deleted (dead after commit `d1d8aa2c0e0`). The `waiting_config` column itself continues to be written to `{}` so existing readers stay happy until they are rewritten in Tasks 9–13.

**Files:**
- Modify: `plugins/discourse-workflows/lib/discourse_workflows/executor/execution_store.rb`
- Modify: `plugins/discourse-workflows/app/models/discourse_workflows/execution_data.rb`
- Test: add a small spec for the ExecutionData `node_contexts` accessor (there is no existing spec file, so create `plugins/discourse-workflows/spec/models/discourse_workflows/execution_data_spec.rb`)
- Modify: `plugins/discourse-workflows/lib/discourse_workflows/executor.rb` (drop `waiting_config: {}` kwarg at the `pause_waiting_execution!` call site)

- [ ] **Step 1: Write a failing test for ExecutionData#node_contexts**

Create `plugins/discourse-workflows/spec/models/discourse_workflows/execution_data_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ExecutionData do
  describe "#node_contexts" do
    it "defaults to an empty hash when absent" do
      data = described_class.new(data: { entries: {}, context: {} }.to_json)
      expect(data.node_contexts).to eq({})
    end

    it "returns the node_contexts key from the parsed JSON blob" do
      data =
        described_class.new(
          data: { entries: {}, context: {}, node_contexts: { "node-1" => { "k" => "v" } } }.to_json,
        )
      expect(data.node_contexts).to eq("node-1" => { "k" => "v" })
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
bin/rspec plugins/discourse-workflows/spec/models/discourse_workflows/execution_data_spec.rb
```

Expected: `NoMethodError: undefined method 'node_contexts'`.

- [ ] **Step 3: Add the accessor to ExecutionData**

Edit `app/models/discourse_workflows/execution_data.rb`. Add this method right below `context_data`:

```ruby
    def node_contexts
      parsed_data["node_contexts"] || {}
    end
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
bin/rspec plugins/discourse-workflows/spec/models/discourse_workflows/execution_data_spec.rb
```

Expected: pass.

- [ ] **Step 5: Rewrite ExecutionStore persistence**

Edit `lib/discourse_workflows/executor/execution_store.rb`.

Delete `self.create_waiting_for_trigger` entirely (lines 10–32).

Replace `pause_waiting_execution!` with:

```ruby
      def pause_waiting_execution!(node:, waiting_until: nil, steps: [])
        execution.update!(
          status: :waiting,
          waiting_node_id: node.id,
          waiting_until: waiting_until,
          resume_token: @execution_context.resume_token,
        )
        save!(steps)
        execution
      end
```

Replace `clear_waiting_execution!` with:

```ruby
      def clear_waiting_execution!
        execution.update!(
          status: :running,
          waiting_node_id: nil,
          waiting_until: nil,
          resume_token: nil,
          timeout_action: nil,
        )
      end
```

Replace `restore_from!` with:

```ruby
      def restore_from!(execution_data)
        @workflow_snapshot_data =
          execution_data&.workflow_data.presence || WorkflowSnapshot.snapshot(workflow)
        @execution_context.restore!(
          context: execution_data&.context_data || {},
          node_contexts: execution_data&.node_contexts || {},
        )
      end
```

Replace `save!` so the JSON blob includes `node_contexts`:

```ruby
      def save!(steps)
        entries = steps_to_entries(steps)
        context = @execution_context.context

        ed = execution.execution_data || execution.build_execution_data
        json_data = {
          "entries" => entries,
          "context" => context,
          "node_contexts" => @execution_context.node_contexts,
        }.to_json

        if json_data.bytesize > MAX_EXECUTION_DATA_SIZE
          Rails.logger.warn(
            "discourse-workflows: execution data for execution #{execution.id} " \
              "exceeds #{MAX_EXECUTION_DATA_SIZE} bytes, truncating context",
          )
          json_data =
            {
              "entries" => entries,
              "context" => {
                "__truncated" => true,
              },
              "node_contexts" => {},
            }.to_json
        end

        ed.update!(data: json_data, workflow_data: @workflow_snapshot_data)
      end
```

Delete the now-unused private `base_waiting_config` method.

- [ ] **Step 6: Update `begin_wait!` in the executor to drop the kwarg**

In `lib/discourse_workflows/executor.rb`, edit the `pause_waiting_execution!` call site (added in Task 5) so it no longer passes `waiting_config:`:

```ruby
      execution =
        @store.pause_waiting_execution!(
          node: @waiting_node,
          waiting_until: resolved,
          steps: @steps,
        )
```

- [ ] **Step 7: Run the executor, node_context, and store-affecting specs**

```bash
bin/rspec \
  plugins/discourse-workflows/spec/lib/discourse_workflows/executor_wait_spec.rb \
  plugins/discourse-workflows/spec/lib/discourse_workflows/nodes/wait/v1_spec.rb \
  plugins/discourse-workflows/spec/lib/discourse_workflows/nodes/form_spec.rb \
  plugins/discourse-workflows/spec/models/discourse_workflows/execution_data_spec.rb
```

Expected: all pass. Service specs (webhook/form) will be rewritten in Tasks 9–12 and are expected to fail after this task until each service is updated.

- [ ] **Step 8: Lint**

```bash
bin/lint \
  plugins/discourse-workflows/lib/discourse_workflows/executor.rb \
  plugins/discourse-workflows/lib/discourse_workflows/executor/execution_store.rb \
  plugins/discourse-workflows/app/models/discourse_workflows/execution_data.rb \
  plugins/discourse-workflows/spec/models/discourse_workflows/execution_data_spec.rb
```

- [ ] **Step 9: Commit**

```bash
git add \
  plugins/discourse-workflows/lib/discourse_workflows/executor.rb \
  plugins/discourse-workflows/lib/discourse_workflows/executor/execution_store.rb \
  plugins/discourse-workflows/app/models/discourse_workflows/execution_data.rb \
  plugins/discourse-workflows/spec/models/discourse_workflows/execution_data_spec.rb
git commit -m "DEV: Write resume_token column and store node_contexts in execution_data"
```

---

## Task 8: Execution model scope and `fail_with_timeout!` updates

Promote `by_resume_token` and drop `waiting_with_type` in favor of a column-only query path. Adjust `fail_with_timeout!` to nil the new columns.

**Files:**
- Modify: `plugins/discourse-workflows/app/models/discourse_workflows/execution.rb`

- [ ] **Step 1: Edit the model**

In `app/models/discourse_workflows/execution.rb`:

Delete the `scope :waiting_with_type, ...` block (currently lines 26-27).

Replace the `by_resume_token` scope with:

```ruby
    scope :by_resume_token,
          ->(token) { where(status: :waiting, resume_token: token.to_s) }
```

In `fail_with_timeout!`, replace the `attrs = { ... }` hash with:

```ruby
        attrs = {
          status: :error,
          error: message,
          finished_at: Time.current,
          waiting_node_id: nil,
          waiting_until: nil,
          resume_token: nil,
          timeout_action: nil,
        }
```

- [ ] **Step 2: Run the model spec**

```bash
bin/rspec plugins/discourse-workflows/spec/models/discourse_workflows/execution_spec.rb
```

Expected: any existing examples that relied on `waiting_config` in the scope/fail paths will fail. Update or delete those examples to reflect the column-based scope. If a test uses `waiting_with_type(:form)`, rewrite it to set `resume_token` + `waiting_node_id` on a fabricated execution and filter by `by_resume_token`.

- [ ] **Step 3: Lint**

```bash
bin/lint plugins/discourse-workflows/app/models/discourse_workflows/execution.rb
```

- [ ] **Step 4: Commit**

```bash
git add plugins/discourse-workflows/app/models/discourse_workflows/execution.rb plugins/discourse-workflows/spec/models/discourse_workflows/execution_spec.rb
git commit -m "DEV: Move Execution.by_resume_token to the resume_token column"
```

---

## Task 9: webhook/receive.rb reads from paused node config

All `waiting_config->>...` reads in `Webhook::Receive` switch to the `execution.workflow.find_node(execution.waiting_node_id)` config.

**Files:**
- Modify: `plugins/discourse-workflows/app/services/discourse_workflows/webhook/receive.rb`
- Test: `plugins/discourse-workflows/spec/services/discourse_workflows/webhook/receive_spec.rb` (rewrite the `waiting_config` fixtures)

- [ ] **Step 1: Rewrite `Webhook::Receive`**

Edit `app/services/discourse_workflows/webhook/receive.rb`.

Replace `fetch_waiting_execution`:

```ruby
    def fetch_waiting_execution(params:)
      return nil if params.execution_id.blank? || params.token.blank?

      execution =
        DiscourseWorkflows::Execution
          .where(status: :waiting)
          .where(resume_token: params.token)
          .find_by(id: params.execution_id)
      return nil unless execution
      return nil unless ActiveSupport::SecurityUtils.secure_compare(execution.resume_token, params.token)

      waiting_node = execution.workflow.find_node(execution.waiting_node_id)
      return nil unless waiting_node

      suffix = params.webhook_suffix.to_s
      stored_suffix = waiting_node.dig("configuration", "webhook_suffix").to_s
      return nil unless suffix == stored_suffix

      execution.lock!("FOR UPDATE SKIP LOCKED")
      execution
    end
```

Replace `validate_waiting_http_method`:

```ruby
    def validate_waiting_http_method(waiting_execution:, params:)
      node = waiting_execution.workflow.find_node(waiting_execution.waiting_node_id)
      unless node&.dig("configuration", "http_method") == params.http_method
        fail!("HTTP method mismatch")
      end
    end
```

Replace `async_resume?`:

```ruby
    def async_resume?(waiting_execution:)
      node = waiting_execution.workflow.find_node(waiting_execution.waiting_node_id)
      response_mode =
        node&.dig("configuration", "response_mode") || Schemas::Webhook::RESPONSE_MODE_IMMEDIATELY
      response_mode == Schemas::Webhook::RESPONSE_MODE_IMMEDIATELY
    end
```

Replace `resume_execution_synchronously`:

```ruby
    def resume_execution_synchronously(waiting_execution:, params:)
      node = waiting_execution.workflow.find_node(waiting_execution.waiting_node_id)
      config = node&.dig("configuration") || {}

      context[:sync_execution] =
        DiscourseWorkflows::Executor.resume(waiting_execution, params.response_items)
      context[:sync_response_mode] = config["response_mode"]
      context[:sync_response_code] = config["response_code"]
    end
```

- [ ] **Step 2: Rewrite the service spec fixtures**

In `spec/services/discourse_workflows/webhook/receive_spec.rb`, search for `waiting_config:` fixtures. For each, replace the stubbed `waiting_config` with a real waiting execution produced by `DiscourseWorkflows::Executor.new(workflow, trigger_id, {}).run` where the workflow contains a `flow:wait` node configured with the desired `http_method`/`response_mode`/`response_code`/`webhook_suffix`/`resume`=webhook. Then set `execution.update!(resume_token: "tok-abc")` so the test's expected token matches.

Example pattern for a single test:

```ruby
  let(:workflow) do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:manual"
        g.node "wait-1",
               "flow:wait",
               configuration: {
                 "resume" => "webhook",
                 "http_method" => "POST",
                 "response_mode" => "immediately",
                 "response_code" => "200",
                 "webhook_suffix" => "",
               }
        g.chain "trigger-1", "wait-1"
      end
    Fabricate(:discourse_workflows_workflow, enabled: true, **graph)
  end

  let(:waiting_execution) do
    execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run
    execution.update!(resume_token: "tok-abc")
    execution
  end
```

Delete any spec that exercised `waiting_config["wait_type"] == "webhook"` discriminator behavior.

- [ ] **Step 3: Run the webhook spec**

```bash
bin/rspec plugins/discourse-workflows/spec/services/discourse_workflows/webhook/receive_spec.rb
```

Expected: pass after the fixture rewrites.

- [ ] **Step 4: Lint**

```bash
bin/lint plugins/discourse-workflows/app/services/discourse_workflows/webhook/receive.rb plugins/discourse-workflows/spec/services/discourse_workflows/webhook/receive_spec.rb
```

- [ ] **Step 5: Commit**

```bash
git add plugins/discourse-workflows/app/services/discourse_workflows/webhook/receive.rb plugins/discourse-workflows/spec/services/discourse_workflows/webhook/receive_spec.rb
git commit -m "DEV: Derive webhook resume behavior from the paused node"
```

---

## Task 10: form/show resolves title/description/fields at read time

`Form::Show#fetch_waiting_execution` filters by the `resume_token` column and in-Ruby checks that the waiting node is `action:form`. `#build_form_data_from_execution` stops reading pre-resolved strings from `waiting_config` and instead resolves expressions against the execution's stored context.

**Files:**
- Modify: `plugins/discourse-workflows/app/services/discourse_workflows/form/show.rb`
- Test: `plugins/discourse-workflows/spec/services/discourse_workflows/form/show_spec.rb`

- [ ] **Step 1: Rewrite `fetch_waiting_execution` and `build_form_data_from_execution`**

In `app/services/discourse_workflows/form/show.rb`:

Replace `fetch_waiting_execution`:

```ruby
    def fetch_waiting_execution(params:)
      return unless params.resume_token

      execution =
        DiscourseWorkflows::Execution.by_resume_token(params.resume_token).first
      return unless execution

      node = execution.workflow.find_node(execution.waiting_node_id)
      return unless node&.dig("type") == "action:form"

      execution
    end
```

Replace `build_form_data_from_execution`:

```ruby
    def build_form_data_from_execution(
      waiting_execution:,
      workflow:,
      form_node:,
      params:,
      guardian:
    )
      resume_token = waiting_execution.resume_token
      context_data = waiting_execution.execution_data&.context_data || {}

      exec_context = {
        "__execution" => {
          "id" => waiting_execution.id,
          "workflow_id" => workflow.id,
          "workflow_name" => workflow.name,
          "resume_url" =>
            "#{Discourse.base_url}/workflows/webhooks/#{waiting_execution.id}?token=#{resume_token}",
        },
      }.merge(context_data)

      config = form_node["configuration"] || {}

      {
        uuid: params.uuid,
        form_title:
          ExpressionResolver.resolve(
            config["form_title"],
            context: exec_context,
            user: guardian.user,
          ),
        form_description:
          ExpressionResolver.resolve(
            config["form_description"],
            context: exec_context,
            user: guardian.user,
          ),
        form_fields: Workflow.resolve_field_keys(config["form_fields"] || []),
        response_mode: "on_received",
        has_downstream_form:
          workflow.node_has_reachable_downstream_of_type?(form_node["id"], "action:form"),
        resume_token: resume_token,
      }
    end
```

- [ ] **Step 2: Update the spec**

Edit `spec/services/discourse_workflows/form/show_spec.rb`. Any test that stubs `waiting_config: { ... }` on a waiting execution should instead:

1. Create a workflow with the relevant `action:form` node containing the desired `form_title`/`form_description`/`form_fields`.
2. Run the workflow to pause it at that form node.
3. Set `execution.update!(resume_token: "tok-xyz")`.
4. Optionally seed `execution.execution_data` context via `execution.build_execution_data.update!(data: { entries: {}, context: {...}, node_contexts: {} }.to_json)` if the test asserts on expression-resolved values.

Remove any assertion that reads pre-resolved `form_title`/`form_description`/`form_fields` from `waiting_config`.

- [ ] **Step 3: Run the spec**

```bash
bin/rspec plugins/discourse-workflows/spec/services/discourse_workflows/form/show_spec.rb
```

Expected: pass.

- [ ] **Step 4: Lint**

```bash
bin/lint plugins/discourse-workflows/app/services/discourse_workflows/form/show.rb plugins/discourse-workflows/spec/services/discourse_workflows/form/show_spec.rb
```

- [ ] **Step 5: Commit**

```bash
git add plugins/discourse-workflows/app/services/discourse_workflows/form/show.rb plugins/discourse-workflows/spec/services/discourse_workflows/form/show_spec.rb
git commit -m "DEV: Resolve form title/description/fields at read time"
```

---

## Task 11: form/resume reads via the column and in-Ruby node-type check

Match the pattern from Task 10.

**Files:**
- Modify: `plugins/discourse-workflows/app/services/discourse_workflows/form/resume.rb`
- Test: `plugins/discourse-workflows/spec/services/discourse_workflows/form/resume_spec.rb`

- [ ] **Step 1: Rewrite `fetch_execution`**

In `app/services/discourse_workflows/form/resume.rb`, replace `fetch_execution`:

```ruby
    def fetch_execution(params:)
      execution =
        DiscourseWorkflows::Execution
          .by_resume_token(params.resume_token)
          .lock("FOR UPDATE SKIP LOCKED")
          .first
      return unless execution

      node = execution.workflow.find_node(execution.waiting_node_id)
      return unless node&.dig("type") == "action:form"

      execution
    end
```

- [ ] **Step 2: Update the spec**

In `spec/services/discourse_workflows/form/resume_spec.rb`, replace waiting_config fixtures with real paused executions (same pattern as Task 10 step 2) whose `waiting_node_id` points at an `action:form` node and whose `resume_token` column matches the test's token.

- [ ] **Step 3: Run the spec**

```bash
bin/rspec plugins/discourse-workflows/spec/services/discourse_workflows/form/resume_spec.rb
```

Expected: pass.

- [ ] **Step 4: Lint**

```bash
bin/lint plugins/discourse-workflows/app/services/discourse_workflows/form/resume.rb plugins/discourse-workflows/spec/services/discourse_workflows/form/resume_spec.rb
```

- [ ] **Step 5: Commit**

```bash
git add plugins/discourse-workflows/app/services/discourse_workflows/form/resume.rb plugins/discourse-workflows/spec/services/discourse_workflows/form/resume_spec.rb
git commit -m "DEV: Filter form resume by resume_token column"
```

---

## Task 12: form/submit drops the dead `trigger_execution` path

`fetch_trigger_execution` and its surrounding logic are dead after the `FormTriggerToken` commit. Remove them and simplify `validate_initial_submission_token` to the token-only branch.

**Files:**
- Modify: `plugins/discourse-workflows/app/services/discourse_workflows/form/submit.rb`
- Test: `plugins/discourse-workflows/spec/services/discourse_workflows/form/submit_spec.rb`

- [ ] **Step 1: Simplify `Form::Submit`**

In `app/services/discourse_workflows/form/submit.rb`:

Delete the `model :trigger_execution, :fetch_trigger_execution, optional: true` line at the top.

Delete the private method `fetch_trigger_execution`.

Simplify `validate_initial_submission_token` to:

```ruby
    def validate_initial_submission_token(workflow:, trigger_node:, params:)
      if params.resume_token.present? &&
           DiscourseWorkflows::FormTriggerToken.valid?(
             params.resume_token,
             workflow_id: workflow.id,
             trigger_node_id: trigger_node["id"],
             uuid: params.uuid,
           )
        return
      end

      fail!(I18n.t("discourse_workflows.errors.invalid_form_token"))
    end
```

Simplify `run_workflow` — remove the `trigger_execution:` parameter and the `if trigger_execution` branch:

```ruby
    def run_workflow(workflow:, trigger_node:, params:, guardian:)
      form_data = DiscourseWorkflows::Workflow.form_data_from(trigger_node, params.form_data)
      form_data.transform_values! { |v| v.is_a?(String) ? v.truncate(MAX_FIELD_VALUE_LENGTH) : v }
      trigger_data = { "form_data" => form_data, "submitted_at" => Time.current.utc.iso8601 }

      options = DiscourseWorkflows::Executor::ExecutionOptions.new(user: guardian.user)
      DiscourseWorkflows::Executor.new(workflow, trigger_node["id"], trigger_data, options).run
    end
```

- [ ] **Step 2: Trim the spec**

In `spec/services/discourse_workflows/form/submit_spec.rb`, delete the entire context block `context "when resume_token from a waiting form_trigger execution is provided"` (the one that uses `ExecutionStore.create_waiting_for_trigger`).

- [ ] **Step 3: Run the spec**

```bash
bin/rspec plugins/discourse-workflows/spec/services/discourse_workflows/form/submit_spec.rb
```

Expected: pass with the trimmed spec.

- [ ] **Step 4: Lint**

```bash
bin/lint plugins/discourse-workflows/app/services/discourse_workflows/form/submit.rb plugins/discourse-workflows/spec/services/discourse_workflows/form/submit_spec.rb
```

- [ ] **Step 5: Commit**

```bash
git add plugins/discourse-workflows/app/services/discourse_workflows/form/submit.rb plugins/discourse-workflows/spec/services/discourse_workflows/form/submit_spec.rb
git commit -m "DEV: Drop dead form_trigger waiting-execution path from Form::Submit"
```

---

## Task 13: Expire + resume-waiting job read `timeout_action` column

Both `Execution::ExpireWaiting#expire_execution` and `Jobs::DiscourseWorkflows::ResumeWaitingExecution` currently read `waiting_config["timeout_action"]` and `waiting_config["timeout_response_items"]`. Switch to the column and drop `timeout_response_items` entirely (test-only fixture, no production writer).

**Files:**
- Modify: `plugins/discourse-workflows/app/services/discourse_workflows/execution/expire_waiting.rb`
- Modify: `plugins/discourse-workflows/app/jobs/regular/discourse_workflows/resume_waiting_execution.rb`
- Test: `plugins/discourse-workflows/spec/services/discourse_workflows/execution/expire_waiting_spec.rb`

- [ ] **Step 1: Update the expire service**

Replace `expire_execution` in `app/services/discourse_workflows/execution/expire_waiting.rb`:

```ruby
    def expire_execution(expired_execution:)
      if expired_execution.timeout_action == "fail"
        expired_execution.fail_with_timeout!
      else
        response_items = expired_execution.waiting_step_input_items
        Executor.resume(expired_execution, response_items)
      end
    end
```

- [ ] **Step 2: Update the resume job**

Replace the body of `Jobs::DiscourseWorkflows::ResumeWaitingExecution#execute` in `app/jobs/regular/discourse_workflows/resume_waiting_execution.rb`:

```ruby
      def execute(args)
        return unless SiteSetting.discourse_workflows_enabled

        execution =
          ::DiscourseWorkflows::Execution
            .includes(:execution_data)
            .where(id: args[:execution_id], status: :waiting)
            .lock("FOR UPDATE SKIP LOCKED")
            .first
        return if execution.nil?
        return if execution.waiting_until.present? && execution.waiting_until > Time.current

        if execution.timeout_action == "fail"
          execution.fail_with_timeout!
        else
          ::DiscourseWorkflows::Executor.resume(execution, execution.waiting_step_input_items)
        end
      end
```

- [ ] **Step 3: Rewrite the expire spec fixture**

In `spec/services/discourse_workflows/execution/expire_waiting_spec.rb`, update `create_waiting_execution` to stop merging `timeout_action`/`timeout_response_items` into `waiting_config`. Instead, after the execution is created, set `execution.update!(timeout_action: timeout_action)` when a timeout action is requested.

Delete any `timeout_response_items` parameter and fixture code. Delete the example `"resumes the expired execution with timeout_response_items"` since the `timeout_response_items` branch no longer exists. The `"when execution uses the default wait ceiling"` example stays.

- [ ] **Step 4: Run the specs**

```bash
bin/rspec \
  plugins/discourse-workflows/spec/services/discourse_workflows/execution/expire_waiting_spec.rb \
  plugins/discourse-workflows/spec/jobs/regular/discourse_workflows/resume_waiting_execution_spec.rb
```

Expected: pass. If the job spec doesn't exist, skip that path.

- [ ] **Step 5: Lint**

```bash
bin/lint \
  plugins/discourse-workflows/app/services/discourse_workflows/execution/expire_waiting.rb \
  plugins/discourse-workflows/app/jobs/regular/discourse_workflows/resume_waiting_execution.rb \
  plugins/discourse-workflows/spec/services/discourse_workflows/execution/expire_waiting_spec.rb
```

- [ ] **Step 6: Commit**

```bash
git add \
  plugins/discourse-workflows/app/services/discourse_workflows/execution/expire_waiting.rb \
  plugins/discourse-workflows/app/jobs/regular/discourse_workflows/resume_waiting_execution.rb \
  plugins/discourse-workflows/spec/services/discourse_workflows/execution/expire_waiting_spec.rb
git commit -m "DEV: Read timeout_action from column in expire + resume paths"
```

---

## Task 14: Drop `waiting_config` column

Post-migrate. With all readers and writers rewritten, the column is safe to drop.

**Files:**
- Create: `plugins/discourse-workflows/db/post_migrate/YYYYMMDDHHMMSS_drop_waiting_config_from_workflow_executions.rb`

- [ ] **Step 1: Generate a new timestamp**

```bash
TS=$(date +%Y%m%d%H%M%S); echo "$TS"
```

- [ ] **Step 2: Create the post-migrate file**

Create `plugins/discourse-workflows/db/post_migrate/<TS>_drop_waiting_config_from_workflow_executions.rb`:

```ruby
# frozen_string_literal: true

class DropWaitingConfigFromWorkflowExecutions < ActiveRecord::Migration[8.0]
  def up
    remove_column :discourse_workflows_executions, :waiting_config
  end

  def down
    add_column :discourse_workflows_executions, :waiting_config, :jsonb, default: {}, null: false
  end
end
```

- [ ] **Step 3: Run the migration**

```bash
bin/rake db:migrate
bin/rake db:migrate RAILS_ENV=test
```

Expected: column removed cleanly.

- [ ] **Step 4: Verify the column is gone**

```bash
bin/rails runner 'puts DiscourseWorkflows::Execution.column_names.include?("waiting_config")'
```

Expected: `false`.

- [ ] **Step 5: Lint**

```bash
bin/lint plugins/discourse-workflows/db/post_migrate/
```

- [ ] **Step 6: Commit**

```bash
git add plugins/discourse-workflows/db/post_migrate/
git commit -m "DEV: Drop waiting_config jsonb column from workflow executions"
```

---

## Task 15: Final verification

Run the full plugin suite to catch any reader or writer missed above.

**Files:** none.

- [ ] **Step 1: Run the whole plugin spec**

```bash
bin/rspec plugins/discourse-workflows/spec
```

Expected: full green. If any example references `waiting_config`, find it, rewrite it to use the new columns/derivations, and commit. Any writer that still tries to set `waiting_config` will raise `ActiveRecord::UnknownAttributeError: unknown attribute 'waiting_config'` — fix by deleting that write.

- [ ] **Step 2: Run the plugin lint**

```bash
bin/lint --fix --recent
```

Expected: no offenses after autofix.

- [ ] **Step 3: Commit any lint/test fixups**

If Step 1 or Step 2 required changes:

```bash
git add -A plugins/discourse-workflows
git commit -m "DEV: Finalize wait-via-context refactor"
```

If no changes were needed, this task is done.
