# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user)
  fab!(:topic)
  fab!(:tag)

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true
    DiscourseWorkflows::Registry.reset!
    DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::TopicClosed)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::AppendTags)
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

      expect(execution.status).to eq("error")
      expect(execution.error).to be_present
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

      expect(execution.status).to eq("error")
      expect(execution.error).to include("not found in workflow snapshot")
    end

    it "follows the correct branch of a condition node" do
      DiscourseWorkflows::Registry.register_condition(DiscourseWorkflows::Conditions::IfCondition)

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
      DiscourseWorkflows::Registry.register_condition(DiscourseWorkflows::Conditions::Filter)

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
      DiscourseWorkflows::Registry.register_condition(DiscourseWorkflows::Conditions::Filter)

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
      DiscourseWorkflows::Registry.register_condition(DiscourseWorkflows::Conditions::Filter)

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
      DiscourseWorkflows::Registry.register_condition(DiscourseWorkflows::Conditions::Filter)

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
      expect(filter_step.metadata["resolved_configuration"]).to be_present
      expect(filter_step.metadata["conditions"]).to be_present
      expect(filter_step.metadata["conditions"].first["passed"]).to eq(true)
      expect(filter_step.status).to eq("success")
    end

    it "marks condition step as filtered when all items fail" do
      DiscourseWorkflows::Registry.register_condition(DiscourseWorkflows::Conditions::Filter)

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
      DiscourseWorkflows::Registry.register_condition(DiscourseWorkflows::Conditions::Filter)
      DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::SetFields)

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
end
