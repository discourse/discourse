# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WaitingExecution do
  fab!(:workflow, :discourse_workflows_workflow)
  fab!(:execution) do
    Fabricate(
      :discourse_workflows_waiting_execution,
      workflow: workflow,
      resume_token: "raw-resume-token",
    )
  end

  def signature_from(url)
    Rack::Utils.parse_query(URI.parse(url).query).fetch("signature")
  end

  it "uses a derived signature in waiting form URLs" do
    url = described_class.form_waiting_url(execution)
    signature = signature_from(url)

    expect(signature).to be_present
    expect(url).not_to include(execution.resume_token)
    expect(described_class.find(execution_id: execution.id, signature: signature)).to eq(execution)
  end

  it "uses a derived signature in waiting webhook URLs" do
    url =
      described_class.webhook_url(execution_id: execution.id, resume_token: execution.resume_token)

    expect(url).not_to include(execution.resume_token)
    expect(described_class.find(execution_id: execution.id, signature: signature_from(url))).to eq(
      execution,
    )
  end

  it "does not accept the raw resume token as a signature" do
    expect(
      described_class.find(execution_id: execution.id, signature: execution.resume_token),
    ).to be_nil
  end

  it "claims an execution using a derived signature" do
    signature = signature_from(described_class.form_waiting_url(execution))

    expect(described_class.claim(execution, signature: signature)).to be_present
    expect(execution.reload.status).to eq("running")
  end
end
