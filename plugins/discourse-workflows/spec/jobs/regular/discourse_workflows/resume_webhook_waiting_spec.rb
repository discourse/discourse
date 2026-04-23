# frozen_string_literal: true

RSpec.describe Jobs::DiscourseWorkflows::ResumeWebhookWaiting do
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, enabled: true) }
  fab!(:execution) do
    Fabricate(:discourse_workflows_execution, workflow: workflow, status: :waiting)
  end

  it "does not resume when the plugin is disabled" do
    SiteSetting.discourse_workflows_enabled = false
    allow(::DiscourseWorkflows::Executor).to receive(:resume)

    described_class.new.execute(execution_id: execution.id)

    expect(::DiscourseWorkflows::Executor).not_to have_received(:resume)
    expect(execution.reload.status).to eq("waiting")
  end
end
