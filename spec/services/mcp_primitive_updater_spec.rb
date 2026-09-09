# frozen_string_literal: true

describe McpPrimitiveUpdater do
  fab!(:admin)

  it "updates primitive exposure and logs the enabled primitive count" do
    McpPrimitive.create!(kind: "tool", identifier: "discourse_search", enabled: true)
    logger = instance_spy(StaffActionLogger, log_custom: nil)
    allow(StaffActionLogger).to receive(:new).with(admin).and_return(logger)

    described_class.update!(actor: admin, primitive_ids: ["tool:discourse_current_user_get"])

    expect(
      McpPrimitive.find_by!(kind: "tool", identifier: "discourse_current_user_get"),
    ).to be_enabled
    expect(McpPrimitive.find_by!(kind: "tool", identifier: "discourse_search")).not_to be_enabled
    expect(logger).to have_received(:log_custom).with("mcp_primitives_updated", primitive_count: 1)
  end

  it "keeps the previous exposure when staff logging fails" do
    primitive =
      McpPrimitive.create!(kind: "tool", identifier: "discourse_current_user_get", enabled: false)
    logger = instance_spy(StaffActionLogger)
    allow(StaffActionLogger).to receive(:new).with(admin).and_return(logger)
    allow(logger).to receive(:log_custom).and_raise(StandardError, "staff logging failed")

    expect do
      described_class.update!(actor: admin, primitive_ids: ["tool:discourse_current_user_get"])
    end.to raise_error(StandardError, "staff logging failed")

    expect(primitive.reload).not_to be_enabled
  end

  it "changes the emergency block inside the staff logging transaction" do
    primitive =
      McpPrimitive.create!(kind: "tool", identifier: "discourse_current_user_get", enabled: true)
    logger = instance_spy(StaffActionLogger)
    allow(StaffActionLogger).to receive(:new).with(admin).and_return(logger)
    allow(logger).to receive(:log_custom).and_raise(StandardError, "staff logging failed")

    expect do
      described_class.set_emergency_block!(
        actor: admin,
        primitive_id: "tool:discourse_current_user_get",
        blocked: true,
      )
    end.to raise_error(StandardError, "staff logging failed")

    expect(primitive.reload).not_to be_emergency_blocked
  end

  it "requires fresh consent when unblocking a consent-relevant primitive" do
    primitive =
      McpPrimitive.create!(
        kind: "tool",
        identifier: "discourse_post_set_deleted",
        enabled: true,
        emergency_blocked: true,
      )
    logger = instance_spy(StaffActionLogger, log_custom: nil)
    allow(StaffActionLogger).to receive(:new).with(admin).and_return(logger)
    allow(McpOauthAuthorization).to receive(:require_consent!)

    described_class.set_emergency_block!(
      actor: admin,
      primitive_id: "tool:discourse_post_set_deleted",
      blocked: false,
    )

    expect(primitive.reload).not_to be_emergency_blocked
    expect(primitive.consent_required_at).to be_present
    expect(McpOauthAuthorization).to have_received(:require_consent!).with(
      scopes: ["mcp:content:write"],
    )
  end
end
