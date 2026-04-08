# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowDependencyIndexer do
  fab!(:admin)

  before { SiteSetting.discourse_workflows_enabled = true }

  def index(workflow)
    described_class.call(workflow)
  end

  def dependency_rows(workflow)
    DiscourseWorkflows::WorkflowDependency.where(workflow_id: workflow.id)
  end

  describe ".call" do
    it "extracts node_type dependencies for every node" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: admin,
          nodes: [
            {
              "id" => "t1",
              "type" => "trigger:webhook",
              "type_version" => "1.0",
              "name" => "Webhook",
              "position_index" => 0,
              "configuration" => {
                "path" => "test",
              },
            },
            {
              "id" => "a1",
              "type" => "action:create_topic",
              "type_version" => "1.0",
              "name" => "Create Topic",
              "position_index" => 1,
              "configuration" => {
              },
            },
          ],
        )

      index(workflow)

      node_types = dependency_rows(workflow).of_type("node_type").pluck(:dependency_key, :node_id)
      expect(node_types).to contain_exactly(%w[trigger:webhook t1], %w[action:create_topic a1])
    end

    it "extracts credential_id dependencies" do
      credential = Fabricate(:discourse_workflows_credential)
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: admin,
          nodes: [
            {
              "id" => "t1",
              "type" => "trigger:webhook",
              "type_version" => "1.0",
              "name" => "Webhook",
              "position_index" => 0,
              "configuration" => {
                "path" => "hook1",
                "credential_id" => credential.id,
              },
            },
          ],
        )

      index(workflow)

      creds = dependency_rows(workflow).of_type("credential_id").pluck(:dependency_key, :node_id)
      expect(creds).to contain_exactly([credential.id.to_s, "t1"])
    end

    it "extracts data_table_id dependencies" do
      data_table = Fabricate(:discourse_workflows_data_table)
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: admin,
          nodes: [
            {
              "id" => "a1",
              "type" => "action:data_table",
              "type_version" => "1.0",
              "name" => "Data Table",
              "position_index" => 0,
              "configuration" => {
                "data_table_id" => data_table.id,
              },
            },
          ],
        )

      index(workflow)

      tables = dependency_rows(workflow).of_type("data_table_id").pluck(:dependency_key, :node_id)
      expect(tables).to contain_exactly([data_table.id.to_s, "a1"])
    end

    it "extracts webhook_path dependencies" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: admin,
          nodes: [
            {
              "id" => "t1",
              "type" => "trigger:webhook",
              "type_version" => "1.0",
              "name" => "Webhook",
              "position_index" => 0,
              "configuration" => {
                "path" => "my-custom-hook",
              },
            },
          ],
        )

      index(workflow)

      paths = dependency_rows(workflow).of_type("webhook_path").pluck(:dependency_key, :node_id)
      expect(paths).to contain_exactly(%w[my-custom-hook t1])
    end

    it "extracts error_workflow dependencies" do
      error_wf = Fabricate(:discourse_workflows_workflow, created_by: admin)
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: admin,
          error_workflow_id: error_wf.id,
          nodes: [
            {
              "id" => "t1",
              "type" => "trigger:schedule",
              "type_version" => "1.0",
              "name" => "Schedule",
              "position_index" => 0,
              "configuration" => {
              },
            },
          ],
        )

      index(workflow)

      error_deps =
        dependency_rows(workflow).of_type("error_workflow").pluck(:dependency_key, :node_id)
      expect(error_deps).to contain_exactly([error_wf.id.to_s, nil])
    end

    it "replaces existing dependencies on re-index" do
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: admin,
          nodes: [
            {
              "id" => "t1",
              "type" => "trigger:webhook",
              "type_version" => "1.0",
              "name" => "Webhook",
              "position_index" => 0,
              "configuration" => {
                "path" => "old-path",
              },
            },
          ],
        )

      index(workflow)
      expect(dependency_rows(workflow).of_type("webhook_path").pluck(:dependency_key)).to eq(
        ["old-path"],
      )

      workflow.update!(
        nodes: [
          {
            "id" => "t1",
            "type" => "trigger:webhook",
            "type_version" => "1.0",
            "name" => "Webhook",
            "position_index" => 0,
            "configuration" => {
              "path" => "new-path",
            },
          },
        ],
      )
      index(workflow)

      expect(dependency_rows(workflow).of_type("webhook_path").pluck(:dependency_key)).to eq(
        ["new-path"],
      )
      expect(dependency_rows(workflow).of_type("node_type").count).to eq(1)
    end

    it "handles workflows with no nodes" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, nodes: [])

      index(workflow)

      expect(dependency_rows(workflow).count).to eq(0)
    end
  end
end
