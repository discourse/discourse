# frozen_string_literal: true

RSpec.describe "Discourse Workflows" do
  fab!(:admin)
  fab!(:tag) { Fabricate(:tag, name: "resolved") }

  let(:workflows_page) { PageObjects::Pages::Workflows.new }
  let(:editor_page) { PageObjects::Pages::WorkflowEditor.new }

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true
    sign_in(admin)
  end

  it "shows empty state on index" do
    workflows_page.visit_index
    expect(workflows_page).to have_no_workflows
  end

  it "creates a workflow with trigger and action" do
    editor_page.visit_new

    expect(editor_page).to have_empty_state_add_node
    editor_page.click_empty_state_add_node
    editor_page.select_node_type("trigger:topic_closed")

    expect(editor_page).to have_node_count(1)

    editor_page.click_add_node
    editor_page.select_node_type("action:append_tags")

    expect(editor_page).to have_node_count(2)

    workflows_page.visit_index
    expect(workflows_page).to have_workflow("My workflow")
  end

  it "creates a workflow with condition node" do
    editor_page.visit_new

    editor_page.click_empty_state_add_node
    editor_page.select_node_type("trigger:topic_closed")

    expect(editor_page).to have_node_count(1)

    editor_page.click_add_node
    editor_page.select_node_type("condition:if")

    expect(editor_page).to have_node_count(2)
    expect(editor_page).to have_node("If")

    workflows_page.visit_index
    expect(workflows_page).to have_workflow("My workflow")
  end

  it "shows a warning icon when the latest workflow run failed" do
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

    DiscourseWorkflows::Execution.create!(
      workflow: workflow,
      status: :error,
      created_at: 1.hour.ago,
    )

    workflows_page.visit_index

    expect(workflows_page).to have_failed_workflow(workflow)
  end

  it "does not show a warning icon when a newer run succeeded" do
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

    DiscourseWorkflows::Execution.create!(
      workflow: workflow,
      status: :error,
      created_at: 2.hours.ago,
    )
    DiscourseWorkflows::Execution.create!(
      workflow: workflow,
      status: :success,
      created_at: 1.hour.ago,
    )

    workflows_page.visit_index

    expect(workflows_page).to have_no_failed_workflow(workflow)
  end
end
