# frozen_string_literal: true

RSpec.describe Jobs::DiscourseWorkflows::ResumeWebhookWaiting do
  subject(:execute_job) do
    described_class.new.execute(execution_id: execution.id, resume_token: execution.resume_token)
  end

  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, published: true) }
  fab!(:execution) do
    Fabricate(
      :discourse_workflows_execution,
      workflow: workflow,
      status: :waiting,
      resume_token: "wait-token",
    )
  end

  it "leaves the execution waiting when the plugin is disabled" do
    SiteSetting.enable_discourse_workflows = false

    expect { execute_job }.not_to change { execution.reload.attributes }
  end

  it "leaves the execution untouched when another worker already claimed it" do
    allow(::DiscourseWorkflows::Execution).to receive(:claim_for_resume).and_return(nil)

    expect { execute_job }.not_to change { execution.reload.attributes }
  end
end
