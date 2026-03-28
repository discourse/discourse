# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user)
  fab!(:topic)
  fab!(:tag)

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true
    DiscourseWorkflows::Registry.reset!
    DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::TopicClosed::V1)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::AppendTags::V1)
  end

  after { DiscourseWorkflows::Registry.reset! }

  def build_workflow
    workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)

    trigger_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:topic_closed",
        name: "Topic Closed",
        position_index: 0,
      )

    action_node =
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "action:append_tags",
        name: "Append Tags",
        position_index: 1,
        configuration: {
          "topic_id" => "={{ trigger.topic_id }}",
          "tag_names" => tag.name,
        },
      )

    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: trigger_node,
      target_node: action_node,
    )

    trigger_node
  end

  describe "#run" do
    it "executes a simple trigger -> action workflow" do
      trigger_node = build_workflow
      trigger_data = { topic_id: topic.id, tags: topic.tags.pluck(:name) }

      executor = described_class.new(trigger_node, trigger_data)
      execution = executor.run

      expect(execution.status).to eq("success")
      expect(topic.reload.tags).to include(tag)
    end

    it "creates an execution record" do
      trigger_node = build_workflow
      trigger_data = { topic_id: topic.id, tags: topic.tags.pluck(:name) }

      executor = described_class.new(trigger_node, trigger_data)

      expect { executor.run }.to change { DiscourseWorkflows::Execution.count }.by(1)
    end

    it "stores context with item arrays in the execution" do
      trigger_node = build_workflow
      trigger_data = { topic_id: topic.id, tags: topic.tags.pluck(:name) }

      executor = described_class.new(trigger_node, trigger_data)
      execution = executor.run

      expect(execution.context["trigger"]["topic_id"]).to eq(topic.id)

      append_tags_output = execution.context["Append Tags"]
      expect(append_tags_output).to be_an(Array)
      expect(append_tags_output.first["json"]["tag_names"]).to eq([tag.name])
    end

    it "handles errors gracefully" do
      trigger_node = build_workflow
      trigger_data = { topic_id: -999, tags: [] }

      executor = described_class.new(trigger_node, trigger_data)
      execution = executor.run

      expect(execution).to have_attributes(status: "error", error: be_present)
    end

    it "fails when trigger node is not in the snapshot" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)
      trigger_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:topic_closed",
          name: "Topic Closed",
          position_index: 0,
        )

      executor = described_class.new(trigger_node, {})
      trigger_node.destroy!

      execution = executor.run

      expect(execution).to have_attributes(
        status: "error",
        error: include("not found in workflow snapshot"),
      )
    end

    it "follows the correct branch of a condition node" do
      DiscourseWorkflows::Registry.register_condition(
        DiscourseWorkflows::Conditions::IfCondition::V1,
      )

      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)

      trigger_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:topic_closed",
          name: "Topic Closed",
          position_index: 0,
        )

      condition_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "condition:if",
          name: "Has Bug Tag",
          position_index: 1,
          configuration: {
            "conditions" => [
              {
                "id" => "1",
                "leftValue" => "tags",
                "rightValue" => "bug",
                "operator" => {
                  "type" => "array",
                  "operation" => "contains",
                },
              },
            ],
            "combinator" => "and",
          },
        )

      true_action =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "action:append_tags",
          name: "Tag Resolved",
          position_index: 2,
          configuration: {
            "topic_id" => "={{ trigger.topic_id }}",
            "tag_names" => tag.name,
          },
        )

      false_tag = Fabricate(:tag, name: "needs-review")
      false_action =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "action:append_tags",
          name: "Tag Needs Review",
          position_index: 3,
          configuration: {
            "topic_id" => "={{ trigger.topic_id }}",
            "tag_names" => false_tag.name,
          },
        )

      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: trigger_node,
        target_node: condition_node,
        source_output: "main",
      )
      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: condition_node,
        target_node: true_action,
        source_output: "true",
      )
      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: condition_node,
        target_node: false_action,
        source_output: "false",
      )

      trigger_data = { topic_id: topic.id, tags: %w[bug help] }
      execution = described_class.new(trigger_node, trigger_data).run

      expect(execution.status).to eq("success")
      expect(topic.reload.tags.map(&:name)).to include(tag.name)
      expect(topic.reload.tags.map(&:name)).not_to include("needs-review")
    end

    it "continues execution when filter passes" do
      DiscourseWorkflows::Registry.register_condition(DiscourseWorkflows::Conditions::Filter::V1)

      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)

      trigger_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:topic_closed",
          name: "Topic Closed",
          position_index: 0,
        )

      filter_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "condition:filter",
          name: "Has Bug Tag",
          position_index: 1,
          configuration: {
            "conditions" => [
              {
                "id" => "1",
                "leftValue" => "tags",
                "rightValue" => "bug",
                "operator" => {
                  "type" => "array",
                  "operation" => "contains",
                },
              },
            ],
            "combinator" => "and",
          },
        )

      action_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "action:append_tags",
          name: "Append Tags",
          position_index: 2,
          configuration: {
            "topic_id" => "={{ trigger.topic_id }}",
            "tag_names" => tag.name,
          },
        )

      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: trigger_node,
        target_node: filter_node,
        source_output: "main",
      )
      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: filter_node,
        target_node: action_node,
        source_output: "true",
      )

      trigger_data = { topic_id: topic.id, tags: %w[bug help] }
      execution = described_class.new(trigger_node, trigger_data).run

      expect(execution.status).to eq("success")
      expect(topic.reload.tags.map(&:name)).to include(tag.name)
    end

    it "supports $json expressions in filter conditions" do
      DiscourseWorkflows::Registry.register_condition(DiscourseWorkflows::Conditions::Filter::V1)

      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)

      trigger_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:topic_closed",
          name: "Topic Closed",
          position_index: 0,
        )

      filter_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "condition:filter",
          name: "Has Bug Tag",
          position_index: 1,
          configuration: {
            "conditions" => [
              {
                "id" => "1",
                "leftValue" => "={{ $json.tags }}",
                "rightValue" => "bug",
                "operator" => {
                  "type" => "array",
                  "operation" => "contains",
                },
              },
            ],
            "combinator" => "and",
          },
        )

      action_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "action:append_tags",
          name: "Append Tags",
          position_index: 2,
          configuration: {
            "topic_id" => "={{ trigger.topic_id }}",
            "tag_names" => tag.name,
          },
        )

      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: trigger_node,
        target_node: filter_node,
        source_output: "main",
      )
      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: filter_node,
        target_node: action_node,
        source_output: "true",
      )

      trigger_data = { topic_id: topic.id, tags: %w[bug help] }
      execution = described_class.new(trigger_node, trigger_data).run

      expect(execution.status).to eq("success")
      expect(topic.reload.tags.map(&:name)).to include(tag.name)

      filter_step = execution.steps.find_by(node: filter_node)
      expect(filter_step.metadata.dig("conditions", 0, "left")).to eq(%w[bug help])
    end

    it "stops execution when filter does not pass" do
      DiscourseWorkflows::Registry.register_condition(DiscourseWorkflows::Conditions::Filter::V1)

      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)

      trigger_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:topic_closed",
          name: "Topic Closed",
          position_index: 0,
        )

      filter_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "condition:filter",
          name: "Has Bug Tag",
          position_index: 1,
          configuration: {
            "conditions" => [
              {
                "id" => "1",
                "leftValue" => "tags",
                "rightValue" => "bug",
                "operator" => {
                  "type" => "array",
                  "operation" => "contains",
                },
              },
            ],
            "combinator" => "and",
          },
        )

      action_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "action:append_tags",
          name: "Append Tags",
          position_index: 2,
          configuration: {
            "topic_id" => "={{ trigger.topic_id }}",
            "tag_names" => tag.name,
          },
        )

      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: trigger_node,
        target_node: filter_node,
        source_output: "main",
      )
      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: filter_node,
        target_node: action_node,
        source_output: "true",
      )

      trigger_data = { topic_id: topic.id, tags: %w[feature help] }
      execution = described_class.new(trigger_node, trigger_data).run

      expect(execution.status).to eq("success")
      expect(topic.reload.tags.map(&:name)).not_to include(tag.name)
    end

    it "stores resolved configuration and result on execution steps" do
      DiscourseWorkflows::Registry.register_condition(DiscourseWorkflows::Conditions::Filter::V1)

      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)

      trigger_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:topic_closed",
          name: "Topic Closed",
          position_index: 0,
        )

      filter_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "condition:filter",
          name: "Check Tags",
          position_index: 1,
          configuration: {
            "conditions" => [
              {
                "id" => "1",
                "leftValue" => "tags",
                "rightValue" => "bug",
                "operator" => {
                  "type" => "array",
                  "operation" => "contains",
                },
              },
            ],
            "combinator" => "and",
          },
        )

      action_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "action:append_tags",
          name: "Append Tags",
          position_index: 2,
          configuration: {
            "topic_id" => "={{ trigger.topic_id }}",
            "tag_names" => tag.name,
          },
        )

      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: trigger_node,
        target_node: filter_node,
        source_output: "main",
      )
      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: filter_node,
        target_node: action_node,
        source_output: "true",
      )

      trigger_data = { topic_id: topic.id, tags: %w[bug help] }
      execution = described_class.new(trigger_node, trigger_data).run

      filter_step = execution.steps.find_by(node: filter_node)
      expect(filter_step).to have_attributes(status: "success")
      expect(filter_step.metadata).to include(
        "resolved_configuration" => be_present,
        "conditions" => be_present,
      )
      expect(filter_step.metadata["conditions"].first["passed"]).to eq(true)
    end

    it "marks condition step as filtered when all items fail" do
      DiscourseWorkflows::Registry.register_condition(DiscourseWorkflows::Conditions::Filter::V1)

      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)

      trigger_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:topic_closed",
          name: "Topic Closed",
          position_index: 0,
        )

      filter_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "condition:filter",
          name: "Check Tags",
          position_index: 1,
          configuration: {
            "conditions" => [
              {
                "id" => "1",
                "leftValue" => "tags",
                "rightValue" => "bug",
                "operator" => {
                  "type" => "array",
                  "operation" => "contains",
                },
              },
            ],
            "combinator" => "and",
          },
        )

      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: trigger_node,
        target_node: filter_node,
        source_output: "main",
      )

      trigger_data = { topic_id: topic.id, tags: %w[feature help] }
      execution = described_class.new(trigger_node, trigger_data).run

      filter_step = execution.steps.find_by(node: filter_node)
      expect(filter_step.status).to eq("filtered")
    end

    it "routes rejected filter items to the false branch" do
      DiscourseWorkflows::Registry.register_condition(DiscourseWorkflows::Conditions::Filter::V1)
      DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::SetFields::V1)

      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)

      trigger_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:topic_closed",
          name: "Topic Closed",
          position_index: 0,
        )

      filter_node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "condition:filter",
          name: "Has Bug Tag",
          position_index: 1,
          configuration: {
            "conditions" => [
              {
                "id" => "1",
                "leftValue" => "tags",
                "rightValue" => "bug",
                "operator" => {
                  "type" => "array",
                  "operation" => "contains",
                },
              },
            ],
            "combinator" => "and",
          },
        )

      false_action =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "action:set_fields",
          name: "Rejected",
          position_index: 2,
          configuration: {
            "include_input" => true,
            "mode" => "manual",
            "fields" => [{ "key" => "rejected", "value" => "yes", "type" => "string" }],
          },
        )

      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: trigger_node,
        target_node: filter_node,
        source_output: "main",
      )
      Fabricate(
        :discourse_workflows_connection,
        workflow: workflow,
        source_node: filter_node,
        target_node: false_action,
        source_output: "false",
      )

      trigger_data = { topic_id: topic.id, tags: %w[feature help] }
      execution = described_class.new(trigger_node, trigger_data).run

      expect(execution.status).to eq("success")
      expect(execution.steps.find_by(node: false_action)).to be_present
      expect(execution.context["Rejected"].first.dig("json", "rejected")).to eq("yes")
    end

    it "skips disabled workflows" do
      trigger_node = build_workflow
      trigger_node.workflow.update!(enabled: false)
      trigger_data = { topic_id: topic.id, tags: topic.tags.pluck(:name) }

      executor = described_class.new(trigger_node, trigger_data)
      execution = executor.run

      expect(execution).to be_nil
    end
  end

  describe "error workflow triggering" do
    before do
      DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Error::V1)
      DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::SetFields::V1)
    end

    def build_error_workflow
      error_wf = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)

      error_trigger =
        Fabricate(
          :discourse_workflows_node,
          workflow: error_wf,
          type: "trigger:error",
          name: "Error Trigger",
          position_index: 0,
        )

      error_action =
        Fabricate(
          :discourse_workflows_node,
          workflow: error_wf,
          type: "action:set_fields",
          name: "Log Error",
          position_index: 1,
          configuration: {
            "include_input" => true,
            "mode" => "manual",
            "fields" => [{ "key" => "handled", "value" => "true", "type" => "string" }],
          },
        )

      Fabricate(
        :discourse_workflows_connection,
        workflow: error_wf,
        source_node: error_trigger,
        target_node: error_action,
      )

      error_wf
    end

    it "triggers the error workflow when a workflow fails" do
      error_wf = build_error_workflow
      trigger_node = build_workflow
      trigger_node.workflow.update!(error_workflow_id: error_wf.id)

      trigger_data = { topic_id: -999, tags: [] }
      executor = described_class.new(trigger_node, trigger_data)
      execution = executor.run

      expect(execution.status).to eq("error")
      expect(execution.execution_mode).to eq("normal")

      error_execution = error_wf.executions.last
      expect(error_execution).to be_present
      expect(error_execution.status).to eq("success")
      expect(error_execution.execution_mode).to eq("error_mode")
      expect(error_execution.trigger_data["workflow_name"]).to eq(trigger_node.workflow.name)
      expect(error_execution.trigger_data["error_message"]).to be_present
    end

    it "does not trigger error workflow for error-mode executions (infinite loop prevention)" do
      error_wf = build_error_workflow
      error_wf.update!(error_workflow_id: error_wf.id)

      trigger_node = build_workflow
      trigger_node.workflow.update!(error_workflow_id: error_wf.id)

      trigger_data = { topic_id: -999, tags: [] }
      executor = described_class.new(trigger_node, trigger_data)
      executor.run

      error_executions = error_wf.executions.where(execution_mode: :error_mode)
      expect(error_executions.count).to eq(1)
    end

    it "does not trigger error workflow when it is the same workflow (self-loop prevention)" do
      trigger_node = build_workflow
      workflow = trigger_node.workflow

      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:error",
        name: "Error Trigger",
        position_index: 2,
      )

      workflow.update!(error_workflow_id: workflow.id)

      trigger_data = { topic_id: -999, tags: [] }
      execution = described_class.new(trigger_node, trigger_data).run

      expect(execution.status).to eq("error")
      expect(workflow.executions.where(execution_mode: :error_mode).count).to eq(0)
    end

    it "does not trigger error workflow when none is configured" do
      trigger_node = build_workflow
      trigger_data = { topic_id: -999, tags: [] }

      expect {
        described_class.new(trigger_node, trigger_data).run
      }.not_to change { DiscourseWorkflows::Execution.where(execution_mode: :error_mode).count }
    end

    it "does not trigger error workflow when it is disabled" do
      error_wf = build_error_workflow
      error_wf.update!(enabled: false)
      trigger_node = build_workflow
      trigger_node.workflow.update!(error_workflow_id: error_wf.id)

      trigger_data = { topic_id: -999, tags: [] }
      execution = described_class.new(trigger_node, trigger_data).run

      expect(execution.status).to eq("error")
      expect(error_wf.executions.count).to eq(0)
    end

    it "does not trigger error workflow when it has no error trigger node" do
      error_wf = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true)
      trigger_node = build_workflow
      trigger_node.workflow.update!(error_workflow_id: error_wf.id)

      trigger_data = { topic_id: -999, tags: [] }
      execution = described_class.new(trigger_node, trigger_data).run

      expect(execution.status).to eq("error")
      expect(error_wf.executions.count).to eq(0)
    end

    it "includes execution context in error trigger data" do
      error_wf = build_error_workflow
      trigger_node = build_workflow
      trigger_node.workflow.update!(error_workflow_id: error_wf.id)

      trigger_data = { topic_id: -999, tags: [] }
      described_class.new(trigger_node, trigger_data).run

      error_execution = error_wf.executions.last
      expect(error_execution.trigger_data).to include(
        "execution_id" => be_a(Integer),
        "workflow_id" => trigger_node.workflow.id,
        "workflow_name" => trigger_node.workflow.name,
        "error_message" => be_present,
      )
    end
  end
end
