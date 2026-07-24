# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowVersion do
  fab!(:user)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: user) }

  describe "defaults" do
    it "uses a connection map by default" do
      expect(described_class.new.connections).to eq({})
    end
  end

  describe "before_destroy guard" do
    it "refuses when the version matches the workflow's current versionId" do
      current = workflow.workflow_versions.find_by(version_id: workflow.version_id)

      expect(current.destroy).to be(false)
      expect(current.errors[:base]).to be_present
      expect(DiscourseWorkflows::WorkflowVersion.exists?(version_id: current.version_id)).to be(
        true,
      )
    end

    it "refuses when the version matches the workflow's activeVersionId" do
      published = Fabricate(:discourse_workflows_workflow, created_by: user, published: true)
      active = published.workflow_versions.find_by(version_id: published.active_version_id)

      published.snapshot!(user: user)

      expect(active.destroy).to be(false)
      expect(DiscourseWorkflows::WorkflowVersion.exists?(version_id: active.version_id)).to be(true)
    end

    it "allows destroy of a superseded version no pointer references" do
      old_version_id = workflow.version_id
      workflow.snapshot!(user: user)
      old = DiscourseWorkflows::WorkflowVersion.find(old_version_id)

      expect { old.destroy! }.to change(DiscourseWorkflows::WorkflowVersion, :count).by(-1)
    end

    it "allows the parent workflow cascade to remove all versions" do
      workflow.snapshot!(user: user)

      expect { workflow.destroy! }.to change(DiscourseWorkflows::WorkflowVersion, :count).by(-2)
    end
  end
end
