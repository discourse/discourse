# frozen_string_literal: true

RSpec.describe Jobs::DiscourseWorkflows::ResumeWaitingExecution do
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, enabled: true) }
  fab!(:execution) do
    Fabricate(
      :discourse_workflows_execution,
      workflow: workflow,
      status: :waiting,
      waiting_until: 1.minute.ago,
    )
  end

  it "does not resume when the plugin is disabled" do
    SiteSetting.discourse_workflows_enabled = false
    allow(::DiscourseWorkflows::Executor).to receive(:resume)

    described_class.new.execute(execution_id: execution.id)

    expect(::DiscourseWorkflows::Executor).not_to have_received(:resume)
    expect(execution.reload.status).to eq("waiting")
  end

  it "does not resume when another caller already claimed the execution" do
    allow(::DiscourseWorkflows::Executor).to receive(:resume)
    allow(::DiscourseWorkflows::Execution).to receive(:claim_for_resume).and_return(nil)

    described_class.new.execute(execution_id: execution.id)

    expect(::DiscourseWorkflows::Executor).not_to have_received(:resume)
  end

  it "does not resume when the execution is no longer waiting" do
    allow(::DiscourseWorkflows::Executor).to receive(:resume)
    execution.update!(status: :running)

    described_class.new.execute(execution_id: execution.id)

    expect(::DiscourseWorkflows::Executor).not_to have_received(:resume)
  end
end
