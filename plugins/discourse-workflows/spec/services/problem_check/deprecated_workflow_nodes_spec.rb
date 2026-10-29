# frozen_string_literal: true

RSpec.describe ProblemCheck::DeprecatedWorkflowNodes do
  subject(:check) { described_class.new }

  fab!(:admin)

  before do
    SiteSetting.enable_discourse_workflows = true
    register_versioned_workflow_nodes(
      "action:problem_check_test",
      v1_deprecation: {
        superseded_by: "2.0",
      },
    )
  end

  def workflow_with(type, name:, type_version: "1.0", published: false)
    graph = build_workflow_graph { |g| g.node "node-1", type, name: "Node", type_version: }
    Fabricate(:discourse_workflows_workflow, created_by: admin, name:, published:, **graph)
  end

  def message_for(*workflows)
    items =
      workflows.map do |workflow|
        "<li><a href=\"/admin/plugins/discourse-workflows/workflows/#{workflow.id}\">#{CGI.escapeHTML(workflow.name)}</a></li>"
      end

    I18n.t("dashboard.problem.deprecated_workflow_nodes", workflows_list: "<ul>#{items.join}</ul>")
  end

  describe "#call" do
    it "lists the workflows that use a deprecated node version" do
      deprecated = workflow_with("action:problem_check_test", name: "Old <workflow>")
      workflow_with("action:problem_check_test", name: "Upgraded workflow", type_version: "2.0")
      workflow_with("action:log", name: "Current workflow")

      expect(check).to have_a_problem.with_priority("low").with_message(message_for(deprecated))
    end

    it "lists a workflow whose published version still uses a deprecated node" do
      workflow = workflow_with("action:problem_check_test", name: "Published", published: true)
      graph =
        build_workflow_graph do |g|
          g.node "node-1", "action:problem_check_test", name: "Node", type_version: "2.0"
        end
      workflow.update!(**graph)
      DiscourseWorkflows::WorkflowDependencyIndexer.call(
        workflow,
        version: workflow.snapshot!(user: admin),
      )

      expect(check).to have_a_problem.with_message(message_for(workflow))
    end

    it "has no problem when no workflow uses a deprecated node version" do
      workflow_with("action:problem_check_test", name: "Upgraded workflow", type_version: "2.0")
      workflow_with("action:log", name: "Current workflow")

      expect(check).to be_chill_about_it
    end

    it "has no problem when workflows are disabled" do
      workflow_with("action:problem_check_test", name: "Old workflow")
      SiteSetting.enable_discourse_workflows = false

      expect(check).to be_chill_about_it
    end
  end
end
