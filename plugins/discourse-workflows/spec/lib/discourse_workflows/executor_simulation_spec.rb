# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user, :admin)

  let(:simulation_options) do
    DiscourseWorkflows::Executor::ExecutionOptions.new(
      user: user,
      execution_mode: :simulation,
      draft_execution: true,
    )
  end

  def build_workflow(&block)
    graph = build_workflow_graph(&block)
    Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)
  end

  def pure_workflow
    build_workflow do |g|
      g.node "trigger-1", "trigger:manual", name: "Run manually"
      g.node "set-1",
             "action:set_fields",
             name: "Set fields",
             configuration: {
               "mode" => "raw",
               "include_other_fields" => true,
               "json_output" => '{"echoed": true}',
             }
      g.chain "trigger-1", "set-1"
    end
  end

  def blocked_workflow
    build_workflow do |g|
      g.node "trigger-1", "trigger:manual", name: "Run manually"
      g.node "flag-1",
             "action:flag_post",
             name: "Flag post",
             configuration: {
               "post_id" => 1,
               "flag_type" => "spam",
             }
      g.chain "trigger-1", "flag-1"
    end
  end

  def run(workflow, options = simulation_options)
    described_class.new(workflow, "trigger-1", { "hello" => "world" }, options).run
  end

  it "runs pure steps and records a simulation execution" do
    execution = run(pure_workflow)

    expect(execution).to be_success
    expect(execution).to be_simulation
    output = execution.execution_data.run_data["Set fields"].first["outputs"].first["items"]
    expect(output.first["json"]).to include("echoed" => true, "hello" => "world")
    expect(execution.execution_data.simulation).to include(
      "effects" => [],
      "total_effect_count" => 0,
      "truncation_reasons" => [],
    )
  end

  it "does not count toward execution stats" do
    workflow = pure_workflow

    expect { run(workflow) }.not_to change { DiscourseWorkflows::ExecutionStat.count }
  end

  it "stops at a step without a simulation adapter and performs nothing" do
    workflow = blocked_workflow

    execution = nil
    expect { execution = run(workflow) }.not_to change { PostAction.count }

    expect(execution).to be_error
    expect(execution.error).to include("Flag post")
    expect(execution.execution_data.simulation).to include(
      "error_kind" => "safety",
      "failed_step" => "Flag post",
    )
  end

  it "stops at a step with configuration issues instead of skipping it" do
    workflow =
      build_workflow do |g|
        g.node "trigger-1", "trigger:manual", name: "Run manually"
        g.node "pm-1",
               "action:send_personal_message",
               name: "Send PM",
               configuration: {
                 "title" => "Hello",
               }
        g.node "set-1",
               "action:set_fields",
               name: "After",
               configuration: {
                 "mode" => "raw",
                 "json_output" => '{"reached": true}',
               }
        g.chain "trigger-1", "pm-1", "set-1"
      end

    execution = run(workflow)

    expect(execution).to be_error
    expect(execution.error).to include("Send PM has configuration issues")
    expect(execution.execution_data.simulation).to include("error_kind" => "safety")
    expect(execution.execution_data.run_data).not_to have_key("After")
  end

  it "stops even when the step is set to continue on error" do
    workflow =
      build_workflow do |g|
        g.node "trigger-1", "trigger:manual", name: "Run manually"
        g.node "flag-1",
               "action:flag_post",
               name: "Flag post",
               configuration: {
                 "post_id" => 1,
                 "flag_type" => "spam",
                 "continueOnFail" => true,
               }
        g.node "set-1",
               "action:set_fields",
               name: "After",
               configuration: {
                 "mode" => "raw",
                 "json_output" => '{"reached": true}',
               }
        g.chain "trigger-1", "flag-1", "set-1"
      end

    execution = run(workflow)

    expect(execution).to be_error
    expect(execution.execution_data.run_data).not_to have_key("After")
  end

  it "never triggers the error workflow" do
    error_workflow = build_workflow { |g| g.node "trigger-1", "trigger:error", name: "On error" }
    workflow = blocked_workflow
    workflow.update!(error_workflow_id: error_workflow.id)

    expect { run(workflow) }.not_to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }
  end

  it "publishes run data to the simulations channel, not the editor channel" do
    workflow = pure_workflow

    messages = MessageBus.track_publish { run(workflow) }
    channels = messages.map(&:channel)

    expect(channels).to include("/discourse-workflows/simulations/#{workflow.id}")
    expect(channels).not_to include("/discourse-workflows/workflow/#{workflow.id}")
  end

  it "leaves static data untouched" do
    workflow =
      build_workflow do |g|
        g.node "trigger-1", "trigger:manual", name: "Run manually"
        g.node "code-1",
               "action:code",
               name: "Touch static data",
               configuration: {
                 "code" =>
                   "const data = getWorkflowStaticData('global'); data.count = 1; return $input.all();",
               }
        g.chain "trigger-1", "code-1"
      end

    run(workflow)

    expect(workflow.reload.static_data).to eq({})
  end

  it "applies workflow pin data like a manual run" do
    workflow = pure_workflow
    workflow.update_node_pin_data!("Run manually", [{ "json" => { "pinned" => true } }])

    execution = run(workflow)
    output = execution.execution_data.run_data["Set fields"].first["outputs"].first["items"]

    expect(output.first["json"]).to include("pinned" => true)
  end

  it "pins the clock for expressions and the code node" do
    pinned = Time.zone.parse("2026-01-02 03:04:05 UTC")
    workflow =
      build_workflow do |g|
        g.node "trigger-1", "trigger:manual", name: "Run manually"
        g.node "set-1",
               "action:set_fields",
               name: "Stamp",
               configuration: {
                 "mode" => "manual",
                 "assignments" => {
                   "assignments" => [
                     {
                       "name" => "at",
                       "value" => "={{ new Date().toISOString() }}",
                       "type" => "string",
                     },
                     { "name" => "now", "value" => "={{ Date.now() }}", "type" => "number" },
                   ],
                 },
               }
        g.node "code-1",
               "action:code",
               name: "Code stamp",
               configuration: {
                 "code" => "return [{ json: { at: new Date().toISOString() } }];",
               }
        g.chain "trigger-1", "set-1", "code-1"
      end
    options =
      DiscourseWorkflows::Executor::ExecutionOptions.new(
        user: user,
        execution_mode: :simulation,
        draft_execution: true,
        now: pinned,
      )

    execution = run(workflow, options)

    expect(execution.error).to be_nil
    stamp = execution.execution_data.run_data["Stamp"].first["outputs"].first["items"].first["json"]
    code =
      execution.execution_data.run_data["Code stamp"].first["outputs"].first["items"].first["json"]
    expect(stamp["at"]).to eq("2026-01-02T03:04:05.000Z")
    expect(stamp["now"]).to eq(pinned.to_i * 1000)
    expect(code["at"]).to eq("2026-01-02T03:04:05.000Z")
    expect(execution.execution_data.simulation["pinned_at"]).to eq(pinned.iso8601(6))
  end

  it "skips the real rate limiter" do
    SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow = 1
    workflow = pure_workflow
    RateLimiter.enable

    manual =
      DiscourseWorkflows::Executor::ExecutionOptions.new(
        user: user,
        execution_mode: :manual,
        draft_execution: true,
      )
    run(workflow, manual)

    expect(run(workflow)).to be_success
  ensure
    RateLimiter.disable
  end
end
