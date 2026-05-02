# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow do
  fab!(:user)

  describe "#trigger_node" do
    it "returns the trigger node" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:topic_closed"
          g.node "action-1", "action:topic_tags"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, **graph)

      trigger = workflow.trigger_node
      expect(trigger).to be_a(Hash)
      expect(trigger["id"]).to eq("trigger-1")
      expect(trigger["type"]).to eq("trigger:topic_closed")
    end
  end

  describe "#node_has_reachable_downstream_of_type?" do
    it "returns true when the target type is a direct downstream" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:form"
          g.node "action-1", "action:form"
          g.chain "trigger-1", "action-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, **graph)

      expect(workflow.node_has_reachable_downstream_of_type?("trigger-1", "action:form")).to be(
        true,
      )
    end

    it "returns true when the target type is separated by intermediate nodes" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:form"
          g.node "action-1", "action:send_message"
          g.node "action-2", "action:form"
          g.chain "trigger-1", "action-1", "action-2"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, **graph)

      expect(workflow.node_has_reachable_downstream_of_type?("trigger-1", "action:form")).to be(
        true,
      )
    end

    it "returns false when no downstream node matches" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:form"
          g.node "action-1", "action:send_message"
          g.chain "trigger-1", "action-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, **graph)

      expect(workflow.node_has_reachable_downstream_of_type?("trigger-1", "action:form")).to be(
        false,
      )
    end

    it "handles cycles without infinite looping" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:form"
          g.node "condition-1", "condition:boolean"
          g.connect "trigger-1", "condition-1"
          g.connect "condition-1", "trigger-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, **graph)

      expect(workflow.node_has_reachable_downstream_of_type?("trigger-1", "action:form")).to be(
        false,
      )
    end
  end

  describe "#each_seconds_schedule_rule" do
    it "only iterates the first MAX_RULES_PER_NODE rules per node" do
      cap = DiscourseWorkflows::ScheduleRule::MAX_RULES_PER_NODE
      rules = Array.new(cap + 3) { { "interval" => "seconds", "seconds_between_triggers" => 30 } }
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:schedule", configuration: { "rules" => rules }
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, **graph)

      indices = []
      workflow.each_seconds_schedule_rule { |_node, _rule, index| indices << index }

      expect(indices).to eq((0...cap).to_a)
    end

    it "skips non-seconds rules within the considered window" do
      rules = [
        { "interval" => "minutes", "minutes_between_triggers" => 5 },
        { "interval" => "seconds", "seconds_between_triggers" => 30 },
        { "interval" => "cron", "cron" => "0 9 * * *" },
        { "interval" => "seconds", "seconds_between_triggers" => 30 },
      ]
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:schedule", configuration: { "rules" => rules }
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, **graph)

      indices = []
      workflow.each_seconds_schedule_rule { |_node, _rule, index| indices << index }

      expect(indices).to eq([1, 3])
    end
  end

  describe "dependent destroy" do
    it "destroys associated executions" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:topic_closed"
          g.node "action-1", "action:topic_tags"
          g.chain "trigger-1", "action-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, **graph)
      Fabricate(:discourse_workflows_execution, workflow: workflow)

      workflow.destroy!

      expect(DiscourseWorkflows::Execution.count).to eq(0)
    end
  end

  describe "#upstream_node_of" do
    fab!(:workflow) do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:topic_created"
          g.node "action-1", "action:topic_tags"
          g.chain "trigger-1", "action-1"
        end
      Fabricate(:discourse_workflows_workflow, created_by: user, **graph)
    end

    it "returns the upstream node for a node_id" do
      upstream = workflow.upstream_node_of("action-1")
      expect(upstream).to include("id" => "trigger-1", "type" => "trigger:topic_created")
    end

    it "coerces integer node ids to strings" do
      graph =
        build_workflow_graph do |g|
          g.node "1", "trigger:topic_created"
          g.node "2", "action:topic_tags"
          g.chain "1", "2"
        end
      numeric_workflow = Fabricate(:discourse_workflows_workflow, created_by: user, **graph)

      expect(numeric_workflow.upstream_node_of(2)).to include("id" => "1")
    end

    it "returns nil when node_id is blank" do
      expect(workflow.upstream_node_of(nil)).to be_nil
      expect(workflow.upstream_node_of("")).to be_nil
    end

    it "returns nil when the node has no incoming connection" do
      expect(workflow.upstream_node_of("trigger-1")).to be_nil
    end

    it "returns nil when no connection targets the given node" do
      expect(workflow.upstream_node_of("missing")).to be_nil
    end
  end

  describe "#last_successful_execution" do
    fab!(:workflow, :discourse_workflows_workflow)

    it "returns nil when there are no executions" do
      expect(workflow.last_successful_execution).to be_nil
    end

    it "returns nil when no execution is successful" do
      Fabricate(:discourse_workflows_execution, workflow: workflow, status: :error)
      Fabricate(:discourse_workflows_execution, workflow: workflow, status: :pending)

      expect(workflow.last_successful_execution).to be_nil
    end

    it "returns the most recent successful execution" do
      Fabricate(
        :discourse_workflows_execution,
        workflow: workflow,
        status: :success,
        created_at: 2.days.ago,
      )
      latest =
        Fabricate(
          :discourse_workflows_execution,
          workflow: workflow,
          status: :success,
          created_at: 1.minute.ago,
        )
      Fabricate(:discourse_workflows_execution, workflow: workflow, status: :error)

      expect(workflow.last_successful_execution).to eq(latest)
    end

    it "eager-loads execution_data" do
      execution = Fabricate(:discourse_workflows_execution, workflow: workflow, status: :success)
      Fabricate(:discourse_workflows_execution_data, execution: execution)

      expect(workflow.last_successful_execution.association(:execution_data)).to be_loaded
    end
  end
end
