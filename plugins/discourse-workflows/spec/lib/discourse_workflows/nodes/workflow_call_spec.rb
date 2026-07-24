# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::WorkflowCall::V1 do
  fab!(:admin)

  def assignment(name, value, type: "string")
    { "name" => name, "type" => type, "value" => value }
  end

  def execute_workflow(workflow, trigger_node_id: "trigger-1", trigger_data: { "name" => "Ada" })
    executor =
      DiscourseWorkflows::Executor.new(
        workflow,
        trigger_node_id,
        trigger_data,
        DiscourseWorkflows::Executor::ExecutionOptions.new(
          user: admin,
          workflow_version: workflow.active_version,
        ),
      )
    executor.run
    executor.execution
  end

  def run_workflow_call_job
    job = Jobs::DiscourseWorkflows::RunWorkflowCall.jobs.shift
    expect(job).to be_present

    Jobs::DiscourseWorkflows::RunWorkflowCall.new.execute(job["args"].first.symbolize_keys)
  end

  def run_workflow_call_jobs
    count = 0

    while Jobs::DiscourseWorkflows::RunWorkflowCall.jobs.any?
      run_workflow_call_job
      count += 1
    end

    count
  end

  def resume_child_execution(child_execution, response_items = nil)
    claimed = DiscourseWorkflows::Execution.claim_for_resume(child_execution.reload)
    expect(claimed).to be_present

    DiscourseWorkflows::Executor.resume(claimed, response_items || claimed.waiting_step_input_items)
  end

  def expect_parent_waiting_at_call(execution, node_id: "call-1")
    expect(execution).to have_attributes(
      status: "waiting",
      waiting_node_id: node_id,
      waiting_until: nil,
    )

    call_step = execution.execution_data.find_step(node_id: node_id)
    expect(call_step["status"]).to eq("waiting")
    expect(Jobs::DiscourseWorkflows::ResumeWaitingExecution.jobs).to be_empty
    call_step
  end

  def serialized_step(execution, node_id: "call-1")
    serialized_execution =
      DiscourseWorkflows::ExecutionSerializer.new(execution.reload, root: false).as_json

    serialized_execution[:steps].find { |step| step[:node_id] == node_id }
  end

  def expected_called_by(caller, execution, node_id: "call-1", node_name: "Call workflow")
    {
      "workflow_id" => caller.id,
      "workflow_name" => caller.name,
      "execution_id" => execution.id,
      "execution_url" =>
        "#{Discourse.base_url}/admin/plugins/discourse-workflows/workflows/" \
          "#{caller.id}/executions/#{execution.id}",
      "node_id" => node_id,
      "node_name" => node_name,
      "node_type" => "action:workflow_call",
    }
  end

  def callable_workflow_with_set_fields(assignments, trigger_id: "call-trigger")
    graph =
      build_workflow_graph do |workflow_graph|
        workflow_graph.node trigger_id, "trigger:workflow_call", name: "Workflow call"
        workflow_graph.node "set-fields",
                            "action:set_fields",
                            name: "Set fields",
                            configuration: {
                              "assignments" => {
                                "assignments" => assignments,
                              },
                            }
        workflow_graph.chain trigger_id, "set-fields"
      end

    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
  end

  def callable_workflow_with_wait(
    wait_type,
    wait_configuration,
    assignments: [assignment("called", "yes")]
  )
    graph =
      build_workflow_graph do |workflow_graph|
        workflow_graph.node "call-trigger", "trigger:workflow_call", name: "Workflow call"
        workflow_graph.node "wait-1", wait_type, name: "Wait", configuration: wait_configuration
        workflow_graph.node "set-fields",
                            "action:set_fields",
                            name: "Set fields",
                            configuration: {
                              "assignments" => {
                                "assignments" => assignments,
                              },
                            }
        workflow_graph.chain "call-trigger", "wait-1", "set-fields"
      end

    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
  end

  def caller_workflow_for(target, call_configuration: {}, after_call: false)
    caller_graph =
      build_workflow_graph do |workflow_graph|
        workflow_graph.node "trigger-1", "trigger:manual", name: "Manual"
        workflow_graph.node "call-1",
                            "action:workflow_call",
                            name: "Call workflow",
                            configuration: { "workflow_id" => target.id }.merge(call_configuration)
        if after_call
          workflow_graph.node "after",
                              "action:set_fields",
                              name: "After",
                              configuration: {
                                "assignments" => {
                                  "assignments" => [assignment("after", "yes")],
                                },
                              }
          workflow_graph.chain "trigger-1", "call-1", "after"
        else
          workflow_graph.chain "trigger-1", "call-1"
        end
      end

    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **caller_graph)
  end

  def failing_callable_workflow
    graph =
      build_workflow_graph do |workflow_graph|
        workflow_graph.node "call-trigger", "trigger:workflow_call", name: "Workflow call"
        workflow_graph.node "wait-1",
                            "flow:wait",
                            name: "Invalid wait",
                            configuration: {
                              "resume" => "time_interval",
                              "wait_amount" => 0,
                              "wait_unit" => "seconds",
                            }
        workflow_graph.chain "call-trigger", "wait-1"
      end

    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
  end

  describe "#execute" do
    it "pauses the parent, runs a published callable workflow job, and returns its output" do
      target = callable_workflow_with_set_fields([assignment("called", "yes")])
      caller = caller_workflow_for(target)

      execution = execute_workflow(caller)
      call_step = expect_parent_waiting_at_call(execution)

      expect(Jobs::DiscourseWorkflows::RunWorkflowCall.jobs.size).to eq(1)
      expect(call_step["metadata"] || {}).not_to have_key("workflow_call")
      workflow_call_run = serialized_step(execution)[:workflow_call_run]
      expect(workflow_call_run).to include(
        "workflow_id" => target.id,
        "workflow_name" => target.name,
        "status" => "pending",
      )
      expect(workflow_call_run).not_to have_key("execution_id")

      expect(run_workflow_call_jobs).to eq(1)

      execution.reload
      call_step = execution.execution_data.find_step(node_id: "call-1")
      expect(execution).to be_success
      expect(call_step["output"].map { |item| item["json"] }).to eq(
        [{ "name" => "Ada", "called" => "yes" }],
      )
      expect(call_step.dig("output", 0, "json")).not_to have_key("workflow_call")
      expect(call_step["metadata"] || {}).not_to have_key("workflow_call")
      expect(serialized_step(execution)[:workflow_call_run]).to include(
        "workflow_id" => target.id,
        "workflow_name" => target.name,
        "execution_id" => DiscourseWorkflows::WorkflowCallRun.last.child_execution_id,
        "status" => "success",
      )
    end

    it "records caller details on the called workflow trigger" do
      target =
        callable_workflow_with_set_fields(
          [assignment("called_by", "={{ $execution.called_by }}", type: "object")],
        )
      caller = caller_workflow_for(target)

      execution = execute_workflow(caller)
      expect_parent_waiting_at_call(execution)
      run_workflow_call_jobs

      execution.reload
      call_step = execution.execution_data.find_step(node_id: "call-1")
      child_execution_id = serialized_step(execution).dig(:workflow_call_run, "execution_id")
      child_execution = DiscourseWorkflows::Execution.find(child_execution_id)
      trigger_step = child_execution.execution_data.find_step(node_id: "call-trigger")
      expected_caller = expected_called_by(caller, execution)

      expect(execution).to be_success
      expect(call_step.dig("output", 0, "json", "called_by")).to eq(expected_caller)
      expect(trigger_step.dig("output", 0, "json", "name")).to eq("Ada")
      expect(trigger_step.dig("output", 0, "json")).not_to have_key("workflow_call")
      expect(trigger_step["metadata"] || {}).not_to have_key("workflow_call")
    end

    it "passes every input item to the sub-workflow in a single call" do
      target = callable_workflow_with_set_fields([assignment("called", "yes")])
      caller = caller_workflow_for(target)

      execution =
        execute_workflow(caller, trigger_data: [{ "name" => "Ada" }, { "name" => "Grace" }])
      expect_parent_waiting_at_call(execution)

      expect(run_workflow_call_jobs).to eq(1)
      expect(DiscourseWorkflows::WorkflowCallRun.count).to eq(1)

      execution.reload
      call_step = execution.execution_data.find_step(node_id: "call-1")
      workflow_call_run = serialized_step(execution)[:workflow_call_run]
      child_execution_id = workflow_call_run["execution_id"]
      child_execution = DiscourseWorkflows::Execution.find(child_execution_id)
      trigger_step = child_execution.execution_data.find_step(node_id: "call-trigger")

      expect(execution).to be_success
      expect(call_step["metadata"] || {}).not_to have_key("workflow_call")
      expect(workflow_call_run["run_id"]).to eq(DiscourseWorkflows::WorkflowCallRun.last.id)
      expect(trigger_step.dig("output").map { |item| item.dig("json", "name") }).to eq(
        %w[Ada Grace],
      )
    end

    it "passes manually mapped fields to the sub-workflow" do
      target = callable_workflow_with_set_fields([assignment("called", "yes")])
      caller =
        caller_workflow_for(
          target,
          call_configuration: {
            "mapping_mode" => "manual",
            "fields" => {
              "assignments" => [
                assignment("full_name", "={{ $json.name }}"),
                assignment("profile.score", "12.5", type: "number"),
                assignment("active", "true", type: "boolean"),
                assignment("tags", '["workflow"]', type: "array"),
                assignment("source", "={{ $json }}", type: "object"),
              ],
            },
          },
        )

      execution =
        execute_workflow(caller, trigger_data: [{ "name" => "Ada" }, { "name" => "Grace" }])
      expect_parent_waiting_at_call(execution)

      expect(run_workflow_call_jobs).to eq(1)

      execution.reload
      call_step = execution.execution_data.find_step(node_id: "call-1")
      child_execution_id = serialized_step(execution).dig(:workflow_call_run, "execution_id")
      child_execution = DiscourseWorkflows::Execution.find(child_execution_id)
      trigger_step = child_execution.execution_data.find_step(node_id: "call-trigger")
      expected_items = [
        {
          "full_name" => "Ada",
          "profile" => {
            "score" => 12.5,
          },
          "active" => true,
          "tags" => ["workflow"],
          "source" => {
            "name" => "Ada",
          },
        },
        {
          "full_name" => "Grace",
          "profile" => {
            "score" => 12.5,
          },
          "active" => true,
          "tags" => ["workflow"],
          "source" => {
            "name" => "Grace",
          },
        },
      ]

      expect(execution).to be_success
      expect(trigger_step["output"].map { |item| item["json"] }).to eq(expected_items)
      expect(call_step["output"].map { |item| item["json"] }).to eq(
        expected_items.map { |item| item.merge("called" => "yes") },
      )
    end

    it "returns the last node output" do
      target_graph =
        build_workflow_graph do |workflow_graph|
          workflow_graph.node "call-trigger", "trigger:workflow_call", name: "Workflow call"
          workflow_graph.node "first",
                              "action:set_fields",
                              name: "First",
                              configuration: {
                                "assignments" => {
                                  "assignments" => [assignment("first", "yes")],
                                },
                              }
          workflow_graph.node "second",
                              "action:set_fields",
                              name: "Second",
                              configuration: {
                                "assignments" => {
                                  "assignments" => [assignment("second", "yes")],
                                },
                              }
          workflow_graph.chain "call-trigger", "first", "second"
        end
      target =
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **target_graph)
      caller = caller_workflow_for(target)

      execution = execute_workflow(caller)
      expect_parent_waiting_at_call(execution)
      run_workflow_call_jobs

      execution.reload
      call_step = execution.execution_data.find_step(node_id: "call-1")
      expect(execution).to be_success
      expect(call_step["output"].map { |item| item["json"] }).to eq(
        [{ "name" => "Ada", "first" => "yes", "second" => "yes" }],
      )
    end

    it "fails the node when a manual object field is invalid JSON" do
      target = callable_workflow_with_set_fields([assignment("called", "yes")])
      caller =
        caller_workflow_for(
          target,
          call_configuration: {
            "mapping_mode" => "manual",
            "fields" => {
              "assignments" => [assignment("payload", "{ not valid json", type: "object")],
            },
          },
        )

      execution = execute_workflow(caller)

      call_step = execution.execution_data.find_step(node_id: "call-1")
      expect(execution).to be_error
      expect(call_step["status"]).to eq("error")
      expect(call_step["error"]).to include("Invalid field value")
      expect(Jobs::DiscourseWorkflows::RunWorkflowCall.jobs).to be_empty
    end

    it "fails the node when the trigger payload exceeds the size budget" do
      max_bytes = DiscourseWorkflows::WorkflowCallPreparer::MAX_TRIGGER_DATA_BYTES
      target = callable_workflow_with_set_fields([assignment("called", "yes")])
      caller =
        caller_workflow_for(
          target,
          call_configuration: {
            "mapping_mode" => "manual",
            "fields" => {
              "assignments" => [assignment("blob", "x" * (max_bytes + 1))],
            },
          },
        )

      execution = execute_workflow(caller)

      call_step = execution.execution_data.find_step(node_id: "call-1")
      expect(execution).to be_error
      expect(call_step["status"]).to eq("error")
      expect(call_step["error"]).to include(
        I18n.t("discourse_workflows.errors.workflow_call.payload_too_large", max: max_bytes),
      )
      expect(Jobs::DiscourseWorkflows::RunWorkflowCall.jobs).to be_empty
    end

    [
      [
        "flow wait",
        "flow:wait",
        { "resume" => "time_interval", "wait_amount" => 1, "wait_unit" => "seconds" },
      ],
      ["webhook wait", "flow:wait", { "resume" => "webhook" }],
      [
        "form wait",
        "action:form",
        {
          "form_title" => "Approval",
          "form_fields" => [{ "field_label" => "Reason", "field_type" => "text" }],
        },
      ],
      [
        "modal wait",
        "action:modal",
        lambda do
          {
            "target_user" => admin.username,
            "title" => "Approve?",
            "body" => "Choose an option",
            "buttons" => {
              "values" => [{ "label" => "Approve", "value" => "approve", "style" => "primary" }],
            },
          }
        end,
      ],
    ].each do |label, wait_type, wait_configuration|
      it "keeps the parent waiting while a child #{label} is waiting" do
        allow(MessageBus).to receive(:publish)
        resolved_wait_configuration =
          if wait_configuration.respond_to?(:call)
            instance_exec(&wait_configuration)
          else
            wait_configuration
          end
        target = callable_workflow_with_wait(wait_type, resolved_wait_configuration)
        caller = caller_workflow_for(target)

        execution = execute_workflow(caller)
        expect_parent_waiting_at_call(execution)
        run_workflow_call_job

        run = DiscourseWorkflows::WorkflowCallRun.last
        child_execution = run.child_execution
        expect(run).to be_waiting
        expect(child_execution).to be_waiting
        expect(execution.reload).to be_waiting
        expect(
          Jobs::DiscourseWorkflows::ResumeWaitingExecution.jobs.map do |job|
            job["args"].first["execution_id"]
          end,
        ).to include(child_execution.id)

        resume_child_execution(child_execution, [{ "json" => { "approved" => true } }])

        execution.reload
        call_step = execution.execution_data.find_step(node_id: "call-1")
        expect(execution).to be_success
        expect(call_step["output"].map { |item| item["json"] }).to eq(
          [{ "approved" => true, "called" => "yes" }],
        )
      end
    end

    it "keeps $execution.called_by available to child nodes after the child waits and resumes" do
      target =
        callable_workflow_with_wait(
          "flow:wait",
          { "resume" => "webhook" },
          assignments: [assignment("called_by", "={{ $execution.called_by }}", type: "object")],
        )
      caller = caller_workflow_for(target)

      execution = execute_workflow(caller)
      expect_parent_waiting_at_call(execution)
      run_workflow_call_job

      child_execution = DiscourseWorkflows::WorkflowCallRun.last.child_execution
      expect(child_execution).to be_waiting

      resume_child_execution(child_execution, [{ "json" => { "approved" => true } }])

      set_fields_step = child_execution.reload.execution_data.find_step(node_id: "set-fields")
      expect(execution.reload).to be_success
      expect(set_fields_step.dig("output", 0, "json", "called_by")).to eq(
        expected_called_by(caller, execution),
      )
    end

    it "fails the parent node when the async child execution fails" do
      target = failing_callable_workflow
      caller = caller_workflow_for(target)

      execution = execute_workflow(caller)
      expect_parent_waiting_at_call(execution)
      run_workflow_call_jobs

      execution.reload
      call_step = execution.execution_data.find_step(node_id: "call-1")
      run = DiscourseWorkflows::WorkflowCallRun.last
      expect(execution).to be_error
      expect(execution.error).to include("finished with status 'error'")
      expect(call_step["status"]).to eq("error")
      expect(call_step["error"]).to include("finished with status 'error'")
      expect(run).to be_error
    end

    it "continues through regular output when an async child failure uses continueOnFail" do
      target = failing_callable_workflow
      caller =
        caller_workflow_for(
          target,
          call_configuration: {
            "continueOnFail" => true,
          },
          after_call: true,
        )

      execution = execute_workflow(caller)
      expect_parent_waiting_at_call(execution)
      run_workflow_call_jobs

      execution.reload
      call_step = execution.execution_data.find_step(node_id: "call-1")
      after_step = execution.execution_data.find_step(node_id: "after")
      expect(execution).to be_success
      expect(call_step["status"]).to eq("success")
      expect(call_step.dig("metadata", "handled_error", "message")).to include(
        "finished with status 'error'",
      )
      expect(after_step.dig("input", 0, "json")).to include("name" => "Ada")
    end

    it "routes async child failures through the error output" do
      target = failing_callable_workflow
      caller_graph =
        build_workflow_graph do |workflow_graph|
          workflow_graph.node "trigger-1", "trigger:manual", name: "Manual"
          workflow_graph.node "call-1",
                              "action:workflow_call",
                              name: "Call workflow",
                              configuration: {
                                "workflow_id" => target.id,
                                "onError" => "continueErrorOutput",
                              }
          workflow_graph.node "after",
                              "action:set_fields",
                              name: "After",
                              configuration: {
                                "assignments" => {
                                  "assignments" => [assignment("after", "yes")],
                                },
                              }
          workflow_graph.connect "trigger-1", "call-1"
          workflow_graph.connect "call-1", "after", output: 1
        end
      caller =
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **caller_graph)

      execution = execute_workflow(caller)
      expect_parent_waiting_at_call(execution)
      run_workflow_call_jobs

      execution.reload
      call_step = execution.execution_data.find_step(node_id: "call-1")
      after_step = execution.execution_data.find_step(node_id: "after")
      expect(execution).to be_success
      expect(call_step["status"]).to eq("success")
      expect(after_step.dig("input", 0, "json")).to include("name" => "Ada")
      expect(after_step.dig("input", 0, "error", "message")).to include(
        "finished with status 'error'",
      )
      expect(after_step.dig("input", 0, "pairedItem")).to eq("item" => 0)
    end

    it "fails the parent when a waiting child times out" do
      target =
        callable_workflow_with_wait(
          "flow:wait",
          {
            "resume" => "webhook",
            "limit_wait_time" => true,
            "timeout_amount" => 1,
            "timeout_unit" => "seconds",
          },
        )
      caller = caller_workflow_for(target)

      execution = execute_workflow(caller)
      expect_parent_waiting_at_call(execution)
      run_workflow_call_job

      run = DiscourseWorkflows::WorkflowCallRun.last
      child_execution = run.child_execution
      expect(child_execution).to be_waiting

      child_execution.fail_with_timeout!

      execution.reload
      call_step = execution.execution_data.find_step(node_id: "call-1")
      expect(execution).to be_error
      expect(call_step["status"]).to eq("error")
      expect(call_step["error"]).to include("timed out")
      expect(run.reload).to be_error
    end

    it "ignores duplicate child terminal hooks" do
      target = callable_workflow_with_set_fields([assignment("called", "yes")])
      caller = caller_workflow_for(target)

      execution = execute_workflow(caller)
      expect_parent_waiting_at_call(execution)
      run_workflow_call_jobs

      run = DiscourseWorkflows::WorkflowCallRun.last
      child_execution = run.child_execution
      original_steps = execution.reload.execution_data.reload.steps_array

      expect {
        DiscourseWorkflows::WorkflowCallContinuation.child_succeeded!(child_execution.reload)
      }.not_to change { execution.reload.execution_data.reload.steps_array }
      expect(execution).to be_success
      expect(original_steps).to eq(execution.execution_data.steps_array)
    end

    it "preserves the workflow-call stack when a child resumes after waiting" do
      caller_graph =
        build_workflow_graph do |workflow_graph|
          workflow_graph.node "trigger-1", "trigger:workflow_call"
        end
      caller =
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **caller_graph)
      target_graph =
        build_workflow_graph do |workflow_graph|
          workflow_graph.node "target-trigger", "trigger:workflow_call", name: "Target trigger"
          workflow_graph.node "wait-1", "flow:wait", configuration: { "resume" => "webhook" }
          workflow_graph.node "target-call",
                              "action:workflow_call",
                              name: "Target call",
                              configuration: {
                                "workflow_id" => caller.id,
                              }
          workflow_graph.chain "target-trigger", "wait-1", "target-call"
        end
      target =
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **target_graph)
      updated_caller_graph =
        build_workflow_graph do |workflow_graph|
          workflow_graph.node "trigger-1", "trigger:workflow_call", name: "Caller trigger"
          workflow_graph.node "caller-call",
                              "action:workflow_call",
                              name: "Caller call",
                              configuration: {
                                "workflow_id" => target.id,
                              }
          workflow_graph.chain "trigger-1", "caller-call"
        end
      caller.update!(
        nodes: updated_caller_graph[:nodes],
        connections: updated_caller_graph[:connections],
      )
      version = caller.snapshot!(user: admin)
      caller.publish!(user: admin)
      DiscourseWorkflows::WorkflowDependencyIndexer.call(caller, version: version)

      execution = execute_workflow(caller)
      expect_parent_waiting_at_call(execution, node_id: "caller-call")
      run_workflow_call_job

      run = DiscourseWorkflows::WorkflowCallRun.last
      expect(run).to be_waiting

      resume_child_execution(run.child_execution, [{ "json" => { "approved" => true } }])

      execution.reload
      expect(execution).to be_error
      expect(execution.error).to include("Workflow call loop detected")
      expect(Jobs::DiscourseWorkflows::RunWorkflowCall.jobs).to be_empty
    end

    it "detects recursive workflow calls at runtime" do
      caller_graph =
        build_workflow_graph do |workflow_graph|
          workflow_graph.node "trigger-1", "trigger:workflow_call"
        end
      caller =
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **caller_graph)
      target_graph =
        build_workflow_graph do |workflow_graph|
          workflow_graph.node "target-trigger", "trigger:workflow_call", name: "Target trigger"
          workflow_graph.node "target-call",
                              "action:workflow_call",
                              name: "Target call",
                              configuration: {
                                "workflow_id" => caller.id,
                              }
          workflow_graph.chain "target-trigger", "target-call"
        end
      target =
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **target_graph)
      updated_caller_graph =
        build_workflow_graph do |workflow_graph|
          workflow_graph.node "trigger-1", "trigger:workflow_call", name: "Caller trigger"
          workflow_graph.node "caller-call",
                              "action:workflow_call",
                              name: "Caller call",
                              configuration: {
                                "workflow_id" => target.id,
                              }
          workflow_graph.chain "trigger-1", "caller-call"
        end
      caller.update!(
        nodes: updated_caller_graph[:nodes],
        connections: updated_caller_graph[:connections],
      )
      version = caller.snapshot!(user: admin)
      caller.publish!(user: admin)
      DiscourseWorkflows::WorkflowDependencyIndexer.call(caller, version: version)

      execution = execute_workflow(caller)
      expect_parent_waiting_at_call(execution, node_id: "caller-call")
      run_workflow_call_jobs

      execution.reload
      expect(execution).to be_error
      expect(execution.error).to include("Workflow call loop detected")
    end
  end

  describe "call run cleanup" do
    def completed_call
      target = callable_workflow_with_set_fields([assignment("called", "yes")])
      caller = caller_workflow_for(target)
      execution = execute_workflow(caller)
      run_workflow_call_jobs

      run = DiscourseWorkflows::WorkflowCallRun.last
      [execution.reload, run.reload, caller, target]
    end

    it "removes the run when its executions are purged by retention" do
      _, run, _, _ = completed_call
      SiteSetting.workflow_executions_retention_days = 30
      DiscourseWorkflows::Execution.update_all(created_at: 60.days.ago)

      DiscourseWorkflows::Execution.purge_old

      expect(DiscourseWorkflows::WorkflowCallRun.exists?(run.id)).to eq(false)
    end

    it "removes the run when its executions are deleted by an admin" do
      _, run, _, _ = completed_call

      DiscourseWorkflows::Execution::Destroy.call(
        params: {
          execution_ids: [run.parent_execution_id, run.child_execution_id],
        },
        guardian: admin.guardian,
      )

      expect(DiscourseWorkflows::WorkflowCallRun.exists?(run.id)).to eq(false)
    end

    it "removes the run when the caller workflow is destroyed" do
      _, run, caller, _ = completed_call

      DiscourseWorkflows::Workflow::Destroy.call(
        params: {
          workflow_id: caller.id,
        },
        guardian: admin.guardian,
      )

      expect(DiscourseWorkflows::WorkflowCallRun.exists?(run.id)).to eq(false)
    end

    it "clears the back-reference when only the child execution is deleted" do
      _, run, _, _ = completed_call

      DiscourseWorkflows::Execution::Destroy.call(
        params: {
          execution_ids: [run.child_execution_id],
        },
        guardian: admin.guardian,
      )

      expect(run.reload.parent_execution_id).to be_present
      expect(run.child_execution_id).to be_nil
    end
  end
end
