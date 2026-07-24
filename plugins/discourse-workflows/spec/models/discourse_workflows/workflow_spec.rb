# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow do
  fab!(:user)

  describe "defaults" do
    it "uses a connection map by default" do
      expect(described_class.new.connections).to eq({})
    end

    it "uses empty static data by default" do
      expect(described_class.new.static_data).to eq({})
    end
  end

  describe "#has_unpublished_changes?" do
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: user) }

    it "is false for workflows that have never been published" do
      expect(workflow).not_to have_unpublished_changes
    end

    it "is false for published workflows without a draft" do
      workflow.update!(active_version_id: workflow.version_id)

      expect(workflow).not_to have_unpublished_changes
    end

    it "is true for published workflows with draft changes" do
      workflow.update!(active_version_id: workflow.version_id)
      workflow.snapshot!(user: user)

      expect(workflow).to have_unpublished_changes
    end
  end

  describe "#node_static_data" do
    fab!(:workflow) do
      Fabricate(
        :discourse_workflows_workflow,
        created_by: user,
        static_data: {
          "global" => {
            "tenant_id" => "acme",
          },
          "node:Schedule" => {
            "cursor" => "abc",
          },
          "node:Removed Node" => {
            "cursor" => "stale",
          },
        },
      )
    end

    it "reads node-scoped data from flat keys" do
      expect(workflow.node_static_data("Schedule")).to eq("cursor" => "abc")
    end

    it "maps flat node keys to entries by node name" do
      expect(workflow.node_static_data_entries).to eq(
        "Schedule" => {
          "cursor" => "abc",
        },
        "Removed Node" => {
          "cursor" => "stale",
        },
      )
    end

    it "commits global and node state as flat keys" do
      workflow.commit_static_data!(
        global: {
          "tenant_id" => "meta",
        },
        node: {
          "Schedule" => {
            "cursor" => "def",
          },
          "Fresh" => {
            "seen" => 1,
          },
        },
      )

      expect(workflow.reload.static_data).to eq(
        "global" => {
          "tenant_id" => "meta",
        },
        "node:Schedule" => {
          "cursor" => "def",
        },
        "node:Fresh" => {
          "seen" => 1,
        },
      )
    end

    it "ignores non-object static data slots when reading runtime state" do
      workflow.update!(static_data: { "global" => "bad", "node:Schedule" => "bad" })

      expect(workflow.global_static_data).to eq({})
      expect(workflow.node_static_data("Schedule")).to eq({})
      expect(workflow.node_static_data_entries).to eq("Schedule" => {})
    end
  end

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

  describe "errorWorkflowId validation" do
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: user) }

    it "rejects pointing at itself" do
      workflow.error_workflow_id = workflow.id

      expect(workflow).not_to be_valid
      expect(workflow.errors[:error_workflow_id]).to include(
        I18n.t(
          "activerecord.errors.models.discourse_workflows/workflow.attributes.error_workflow_id.cannot_be_self",
        ),
      )
    end

    it "allows pointing at a different workflow" do
      other = Fabricate(:discourse_workflows_workflow, created_by: user)
      workflow.error_workflow_id = other.id

      expect(workflow).to be_valid
    end

    it "allows a nil error workflow" do
      workflow.error_workflow_id = nil

      expect(workflow).to be_valid
    end
  end

  describe "errorWorkflowId back-references on destroy" do
    fab!(:target, :discourse_workflows_workflow)
    fab!(:referrer) do
      Fabricate(:discourse_workflows_workflow, created_by: user, error_workflow_id: target.id)
    end

    it "nullifies errorWorkflowId on workflows that point at the destroyed one" do
      expect { target.destroy! }.to change { referrer.reload.error_workflow_id }.from(target.id).to(
        nil,
      )
    end

    it "leaves unrelated workflows untouched" do
      other = Fabricate(:discourse_workflows_workflow, created_by: user)

      target.destroy!

      expect(other.reload.error_workflow_id).to be_nil
    end

    it "does not stop the destroy" do
      target.destroy!

      expect(DiscourseWorkflows::Workflow.exists?(target.id)).to be(false)
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
