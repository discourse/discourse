# frozen_string_literal: true

RSpec.describe "Workflow tests" do
  fab!(:admin)
  fab!(:recipient, :user)

  let(:tests_page) { PageObjects::Pages::DiscourseWorkflows::WorkflowTests.new }
  let(:executions_page) { PageObjects::Pages::DiscourseWorkflows::Executions.new }
  let(:editor_page) { PageObjects::Pages::DiscourseWorkflows::WorkflowEditor.new }

  before do
    SiteSetting.discourse_workflows_tests_enabled = true
    Jobs.run_immediately!
    sign_in(admin)
  end

  def build_workflow(&block)
    graph = build_workflow_graph(&block)
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
  end

  def pm_workflow
    build_workflow do |builder|
      builder.node "trigger-1", "trigger:manual", name: "Run manually"
      builder.node "pm-1",
                   "action:send_personal_message",
                   name: "Send PM",
                   configuration: {
                     "recipient_usernames" => [recipient.username],
                     "title" => "Hello there",
                     "raw" => "Welcome aboard",
                   }
      builder.chain "trigger-1", "pm-1"
    end
  end

  def completed_run(workflow)
    execution =
      Fabricate(
        :discourse_workflows_completed_execution,
        workflow:,
        trigger_node_id: "trigger-1",
        trigger_data: {
        },
        execution_mode: :manual,
      )
    Fabricate(
      :discourse_workflows_execution_data,
      execution:,
      workflow_data:
        DiscourseWorkflows::WorkflowSnapshot.from_workflow(workflow, published: false).to_h,
    )
    execution
  end

  it "saves a run as a test, runs it, adds a check from the result and sees it go stale" do
    workflow = pm_workflow
    execution = completed_run(workflow)

    executions_page.visit_detail(workflow.id, execution.id)
    find(".workflows-execution-detail__save-as-test").click

    workflow_test = workflow.workflow_tests.last
    expect(tests_page).to have_editor_path(workflow, workflow_test)
    expect(tests_page).to have_name_value("Test from run ##{execution.id}")
    expect(tests_page).to have_check_sentence("Workflow finishes without errors")

    tests_page.run_test
    expect(tests_page).to have_result_state("passed")
    expect(tests_page).to have_effect("A personal message is sent")
    expect(tests_page).to have_effect(recipient.username)

    tests_page.add_first_effect_as_check
    expect(tests_page).to have_check_sentence("A personal message is sent where recipient")
    tests_page.save

    expect(tests_page).to have_index_path(workflow)
    expect(tests_page).to have_row_state(workflow_test, "run_again")

    tests_page.run_row(workflow_test)
    expect(tests_page).to have_row_state(workflow_test, "passed")
  end

  it "previews with current data and saves the preview as a test with suggested checks" do
    workflow = pm_workflow

    tests_page.visit_index(workflow.id).click_preview
    expect(tests_page).to have_preview_effect("A personal message is sent")

    tests_page.save_preview_as_test

    workflow_test = workflow.workflow_tests.last
    expect(tests_page).to have_editor_path(workflow, workflow_test)
    expect(tests_page).to have_check_sentence("Workflow finishes without errors")
    expect(tests_page).to have_check_sentence("A personal message is sent where recipient")
  end

  it "pastes a response for an external call and runs the test against it" do
    workflow =
      build_workflow do |builder|
        builder.node "trigger-1", "trigger:manual", name: "Run manually"
        builder.node "http-1",
                     "action:http_request",
                     name: "Call API",
                     configuration: {
                       "url" => "https://example.com/hook",
                       "method" => "POST",
                     }
        builder.chain "trigger-1", "http-1"
      end
    workflow_test = Fabricate(:discourse_workflows_workflow_test, workflow:)

    tests_page.visit_editor(workflow.id, workflow_test.id)
    expect(tests_page).to have_step_needing_response("Call API")

    tests_page.paste_response("Call API", '{"ok": true}')
    expect(tests_page).to have_replayed_step("Call API")

    tests_page.run_test
    expect(tests_page).to have_result_state("passed")
    expect(tests_page).to have_effect("An HTTP request is made")
  end

  it "warns on the publish banner when a test is failing" do
    workflow = pm_workflow
    workflow_test =
      Fabricate(:discourse_workflows_workflow_test, workflow:, checks: [{ effect: "nothing" }])
    workflow.snapshot!(user: admin)
    DiscourseWorkflows::WorkflowTest::Action::EnqueueRun.call(workflow_test:, user: admin)

    tests_page.visit_index(workflow.id)
    expect(tests_page).to have_row_state(workflow_test, "failed")

    editor_page.visit(workflow.id)
    expect(tests_page).to have_banner_tests_state("failed")
  end
end
