# frozen_string_literal: true

RSpec.describe "Discourse Workflows - Versions" do
  fab!(:admin)
  fab!(:workflow) do
    graph = build_workflow_graph { |builder| builder.node "v1-1", "trigger:manual" }
    Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
  end

  let(:versions_page) { PageObjects::Pages::DiscourseWorkflows::WorkflowVersions.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before { sign_in(admin) }

  it "lists versions with their author and reverts the draft to an older version" do
    first_version = workflow.workflow_versions.order(:version_number).first

    graph = build_workflow_graph { |builder| builder.node "v2-1", "trigger:schedule" }
    workflow.update!(nodes: graph[:nodes], connections: graph[:connections])
    workflow.snapshot!(user: admin)

    versions_page.visit(workflow.id)

    expect(versions_page).to have_versions(2)
    expect(versions_page).to have_author(admin.username)

    versions_page.revert(first_version)
    dialog.click_yes

    expect(page).to have_current_path("/admin/plugins/discourse-workflows/workflows/#{workflow.id}")
    expect(workflow.reload.version_id).to eq(first_version.version_id)
    expect(workflow.nodes).to eq(first_version.nodes)
  end
end
