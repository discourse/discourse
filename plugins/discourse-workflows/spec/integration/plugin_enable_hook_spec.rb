# frozen_string_literal: true

describe "discourse_workflows_enabled site setting hook" do
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, published: true) }
  fab!(:execution) do
    Fabricate(
      :discourse_workflows_execution,
      workflow: workflow,
      status: :waiting,
      waiting_until: 1.minute.ago,
    )
  end

  it "reschedules waiting executions when the setting flips false to true" do
    SiteSetting.discourse_workflows_enabled = false

    expect_enqueued_with(
      job: Jobs::DiscourseWorkflows::ResumeWaitingExecution,
      args: {
        execution_id: execution.id,
      },
    ) { SiteSetting.discourse_workflows_enabled = true }
  end

  it "does not reschedule when the setting flips true to false" do
    SiteSetting.discourse_workflows_enabled = true

    expect_not_enqueued_with(
      job: Jobs::DiscourseWorkflows::ResumeWaitingExecution,
      args: {
        execution_id: execution.id,
      },
    ) { SiteSetting.discourse_workflows_enabled = false }
  end

  it "does not reschedule for unrelated setting changes" do
    SiteSetting.discourse_workflows_enabled = true

    expect_not_enqueued_with(
      job: Jobs::DiscourseWorkflows::ResumeWaitingExecution,
      args: {
        execution_id: execution.id,
      },
    ) { SiteSetting.title = "Different title" }
  end
end
