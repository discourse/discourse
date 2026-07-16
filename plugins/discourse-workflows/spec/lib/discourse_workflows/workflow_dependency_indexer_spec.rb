# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowDependencyIndexer do
  fab!(:admin)

  def index(workflow)
    version = workflow.workflow_versions.find_by(version_id: workflow.version_id)
    described_class.call(workflow, version: version)
  end

  def dependency_rows(workflow)
    DiscourseWorkflows::WorkflowDependency.where(workflow_id: workflow.id)
  end

  describe ".call" do
    it "extracts node_type dependencies for every node" do
      graph =
        build_workflow_graph do |g|
          g.node "t1", "trigger:webhook", configuration: { "path" => "test" }
          g.node "a1", "action:topic"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)

      index(workflow)

      node_types = dependency_rows(workflow).of_type("node_type").pluck(:dependency_key, :node_id)
      expect(node_types).to contain_exactly(%w[trigger:webhook t1], %w[action:topic a1])
    end

    it "extracts credential_id dependencies" do
      credential = Fabricate(:discourse_workflows_credential)
      graph =
        build_workflow_graph do |g|
          g.node "t1",
                 "trigger:webhook",
                 parameters: {
                   "path" => "hook1",
                   "authentication" => "basic_auth",
                 },
                 credentials: {
                   "auth" => {
                     "id" => credential.id,
                     "credential_type" => "basic_auth",
                   },
                 }
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)

      index(workflow)

      creds = dependency_rows(workflow).of_type("credential_id").pluck(:dependency_key, :node_id)
      expect(creds).to contain_exactly([credential.id.to_s, "t1"])
    end

    it "ignores undeclared and hidden credential dependencies" do
      credential = Fabricate(:discourse_workflows_credential)
      graph =
        build_workflow_graph do |g|
          g.node "a1",
                 "action:log",
                 parameters: {
                   "message" => "hello",
                 },
                 credentials: {
                   "auth" => {
                     "id" => credential.id,
                     "credential_type" => "basic_auth",
                   },
                 }
          g.node "t1",
                 "trigger:webhook",
                 parameters: {
                   "path" => "hook1",
                   "authentication" => "none",
                 },
                 credentials: {
                   "auth" => {
                     "id" => credential.id,
                     "credential_type" => "basic_auth",
                   },
                 }
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)

      index(workflow)

      expect(dependency_rows(workflow).of_type("credential_id")).to be_empty
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

    it "extracts workflow_call dependencies" do
      target = Fabricate(:discourse_workflows_workflow, created_by: admin)
      graph =
        build_workflow_graph do |g|
          g.node "a1", "action:workflow_call", configuration: { "workflow_id" => target.id }
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)

      index(workflow)

      workflow_calls =
        dependency_rows(workflow).of_type("workflow_call").pluck(:dependency_key, :node_id)
      expect(workflow_calls).to contain_exactly([target.id.to_s, "a1"])
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

    it "replaces dependencies for the same version on re-index" do
      first_table = Fabricate(:discourse_workflows_data_table)
      second_table = Fabricate(:discourse_workflows_data_table)
      graph =
        build_workflow_graph do |g|
          g.node "a1", "action:data_table", configuration: { "data_table_id" => first_table.id }
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)

      index(workflow)
      expect(dependency_rows(workflow).of_type("data_table_id").pluck(:dependency_key)).to eq(
        [first_table.id.to_s],
      )

      # Reindexing the same versionId should clear and rewrite that version's
      # dependency rows; mutate the snapshot in place to test this.
      snapshot = workflow.workflow_versions.find_by(version_id: workflow.version_id)
      updated_nodes = snapshot.nodes.deep_dup
      updated_nodes.first["parameters"]["data_table_id"] = second_table.id
      snapshot.update!(nodes: updated_nodes)
      index(workflow)

      expect(dependency_rows(workflow).of_type("data_table_id").pluck(:dependency_key)).to eq(
        [second_table.id.to_s],
      )
      expect(dependency_rows(workflow).of_type("node_type").count).to eq(1)
    end

    it "scopes dependency rows per version" do
      first_table = Fabricate(:discourse_workflows_data_table)
      second_table = Fabricate(:discourse_workflows_data_table)
      graph =
        build_workflow_graph do |g|
          g.node "a1", "action:data_table", configuration: { "data_table_id" => first_table.id }
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
      index(workflow)
      old_version_id = workflow.version_id

      updated =
        build_workflow_graph do |g|
          g.node "a1", "action:data_table", configuration: { "data_table_id" => second_table.id }
        end
      workflow.update!(nodes: updated[:nodes])
      workflow.snapshot!(user: workflow.created_by)
      index(workflow)

      expect(
        dependency_rows(workflow).where(workflow_version_id: old_version_id).pluck(:dependency_key),
      ).to include(first_table.id.to_s)
      expect(
        dependency_rows(workflow).where(workflow_version_id: workflow.version_id).pluck(
          :dependency_key,
        ),
      ).to include(second_table.id.to_s)
    end

    it "handles workflows with no nodes" do
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, nodes: [])

      index(workflow)

      expect(dependency_rows(workflow).count).to eq(0)
    end
  end
end
