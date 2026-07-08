# frozen_string_literal: true

describe "enable_discourse_workflows site setting hook" do
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
    SiteSetting.enable_discourse_workflows = false

    expect_enqueued_with(
      job: Jobs::DiscourseWorkflows::ResumeWaitingExecution,
      args: {
        execution_id: execution.id,
      },
    ) { SiteSetting.enable_discourse_workflows = true }
  end

  it "does not reschedule when the setting flips true to false" do
    SiteSetting.enable_discourse_workflows = true

    expect_not_enqueued_with(
      job: Jobs::DiscourseWorkflows::ResumeWaitingExecution,
      args: {
        execution_id: execution.id,
      },
    ) { SiteSetting.enable_discourse_workflows = false }
  end

  it "does not reschedule for unrelated setting changes" do
    SiteSetting.enable_discourse_workflows = true

    expect_not_enqueued_with(
      job: Jobs::DiscourseWorkflows::ResumeWaitingExecution,
      args: {
        execution_id: execution.id,
      },
    ) { SiteSetting.title = "Different title" }
  end
end
