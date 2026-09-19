# frozen_string_literal: true

RSpec.describe "Discourse Workflows - Executions" do
  fab!(:admin)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

  let(:executions_page) { PageObjects::Pages::DiscourseWorkflows::Executions.new }

  before { sign_in(admin) }

  it "lists executions with their status" do
    Fabricate(:discourse_workflows_completed_execution, workflow: workflow)

    executions_page.visit_index

    expect(executions_page).to have_execution_with_status("success")
  end

  it "shows the execution detail view with steps" do
    execution = Fabricate(:discourse_workflows_completed_execution, workflow: workflow)
    Fabricate(
      :discourse_workflows_execution_data_with_steps,
      execution: execution,
      node_name: "Manual Trigger",
      node_type: "trigger:manual",
      step_status: "success",
    )

    executions_page.visit_detail(workflow.id, execution.id)

    expect(executions_page).to have_detail
    expect(executions_page).to have_step("Manual Trigger")
  end
end
