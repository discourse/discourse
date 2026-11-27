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

  describe ".enable_defaults!" do
    it "records a choice for every primitive and enables the defaults" do
      described_class.enable_defaults!

      expect(McpPrimitive.count).to eq(DiscourseMcp.registry.all.size)
      expect(McpPrimitive.exposed.where(kind: "tool").pluck(:identifier)).to include(
        "discourse_update_site_setting",
        "discourse_create_category",
        "discourse_delete_category",
        "discourse_set_theme_code",
        "discourse_install_theme",
        "discourse_sync_remote_theme",
        "discourse_create_topic",
        "discourse_set_topic_pin",
        "discourse_upload_file",
      )
    end

    it "enables only the primitives that opt in" do
      described_class.enable_defaults!

      defaults =
        DiscourseMcp
          .registry
          .all
          .select(&:default_enabled?)
          .map { |primitive| [primitive.kind.to_s, primitive.identifier] }

      expect(defaults).to be_present
      expect(McpPrimitive.exposed.pluck(:kind, :identifier)).to match_array(defaults)
    end

    it "keeps messaging, outbound data, member management and moderation off" do
      described_class.enable_defaults!

      expect(McpPrimitive.exposed.where(kind: "tool").pluck(:identifier)).not_to include(
        "discourse_list_private_messages",
        "discourse_read_private_message",
        "discourse_create_private_message",
        "discourse_invite_group_members",
        "discourse_create_webhook",
        "discourse_list_webhooks",
        "discourse_create_user",
        "discourse_update_user",
        "discourse_manage_user_activation",
        "discourse_suspend_user",
        "discourse_silence_user",
        "discourse_perform_reviewable_action",
        "discourse_set_topic_closed",
        "discourse_post_set_deleted",
      )
    end

    it "logs the change as the system user" do
      described_class.enable_defaults!

      expect(
        UserHistory.where(
          acting_user_id: Discourse.system_user.id,
          custom_type: "mcp_primitives_updated",
        ),
      ).to exist
    end
  end
end
