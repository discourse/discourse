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
      graph =
        build_workflow_graph do |g|
          g.node "t1", "trigger:webhook", configuration: { "path" => "test" }
          g.node "a1", "action:create_topic"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)

      index(workflow)

      node_types = dependency_rows(workflow).of_type("node_type").pluck(:dependency_key, :node_id)
      expect(node_types).to contain_exactly(%w[trigger:webhook t1], %w[action:create_topic a1])
    end

    it "extracts credential_id dependencies" do
      credential = Fabricate(:discourse_workflows_credential)
      graph =
        build_workflow_graph do |g|
          g.node "t1",
                 "trigger:webhook",
                 configuration: {
                   "path" => "hook1",
                   "credential_id" => credential.id,
                 }
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)

      index(workflow)

      creds = dependency_rows(workflow).of_type("credential_id").pluck(:dependency_key, :node_id)
      expect(creds).to contain_exactly([credential.id.to_s, "t1"])
    end

    it "extracts data_table_id dependencies" do
      data_table = Fabricate(:discourse_workflows_data_table)
      graph =
        build_workflow_graph do |g|
          g.node "a1", "action:data_table", configuration: { "data_table_id" => data_table.id }
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)

      index(workflow)

      tables = dependency_rows(workflow).of_type("data_table_id").pluck(:dependency_key, :node_id)
      expect(tables).to contain_exactly([data_table.id.to_s, "a1"])
    end

    it "extracts webhook_path dependencies" do
      graph =
        build_workflow_graph do |g|
          g.node "t1", "trigger:webhook", configuration: { "path" => "my-custom-hook" }
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)

      index(workflow)

      paths = dependency_rows(workflow).of_type("webhook_path").pluck(:dependency_key, :node_id)
      expect(paths).to contain_exactly(%w[my-custom-hook t1])
    end

    it "extracts error_workflow dependencies" do
      error_wf = Fabricate(:discourse_workflows_workflow, created_by: admin)
      graph = build_workflow_graph { |g| g.node "t1", "trigger:schedule" }
      workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: admin,
          error_workflow_id: error_wf.id,
          **graph,
        )

      index(workflow)

      error_deps =
        dependency_rows(workflow).of_type("error_workflow").pluck(:dependency_key, :node_id)
      expect(error_deps).to contain_exactly([error_wf.id.to_s, nil])
    end

    it "replaces existing dependencies on re-index" do
      graph =
        build_workflow_graph do |g|
          g.node "t1", "trigger:webhook", configuration: { "path" => "old-path" }
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)

      index(workflow)
      expect(dependency_rows(workflow).of_type("webhook_path").pluck(:dependency_key)).to eq(
        ["old-path"],
      )

      updated =
        build_workflow_graph do |g|
          g.node "t1", "trigger:webhook", configuration: { "path" => "new-path" }
        end
      workflow.update!(nodes: updated[:nodes])
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
