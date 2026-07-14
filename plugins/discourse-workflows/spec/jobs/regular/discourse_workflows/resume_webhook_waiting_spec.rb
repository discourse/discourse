# frozen_string_literal: true

RSpec.describe Jobs::DiscourseWorkflows::ResumeWebhookWaiting do
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, published: true) }
  fab!(:execution) do
    Fabricate(:discourse_workflows_execution, workflow: workflow, status: :waiting)
  end

  it "leaves the execution waiting when the plugin is disabled" do
    SiteSetting.enable_discourse_workflows = false
    before_updated_at = execution.updated_at

    described_class.new.execute(execution_id: execution.id)

    execution.reload
    expect(execution.status).to eq("waiting")
    expect(execution.updated_at).to eq_time(before_updated_at)
  end

  it "leaves the execution untouched when another worker already claimed it" do
    allow(::DiscourseWorkflows::Execution).to receive(:claim_for_resume).and_return(nil)
    before_updated_at = execution.updated_at

    described_class.new.execute(execution_id: execution.id)

    execution.reload
    expect(execution.status).to eq("waiting")
    expect(execution.updated_at).to eq_time(before_updated_at)
  end
end
