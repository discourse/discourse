# frozen_string_literal: true

describe DiscourseMcp::Tools::UserModerationSupport do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  def invoke(operation, actor: admin, **arguments)
    described_class.call(
      {
        "username" => user.username,
        "confirm" => true,
        "duration_days" => 2,
        "reason" => "Repeated abuse",
      }.merge(arguments.stringify_keys),
      instance_double(
        DiscourseMcp::RequestContext,
        content_policy: DiscourseMcp::ContentPolicy.new([]),
        guardian: actor.guardian,
      ),
      operation,
    )
  end

  describe ".call" do
    it "suspends and restores a user with attributed audit records and verified receipts" do
      freeze_time
      result = invoke("suspend")[:structuredContent]
      expect(user.reload.suspended?).to eq(true)
      expect(user.suspended_till).to be_within(1.second).of(2.days.from_now)
      expect(result[:user][:suspended]).to eq(true)
      expect(result[:actor][:id]).to eq(admin.id)
      expect(
        UserHistory.where(
          action: UserHistory.actions[:suspend_user],
          target_user_id: user.id,
          acting_user_id: admin.id,
        ),
      ).to exist

      result = invoke("unsuspend")[:structuredContent]
      expect(user.reload.suspended?).to eq(false)
      expect(result[:changed]).to eq(true)
      expect(result[:user][:suspended_till]).to be_nil
      expect(invoke("unsuspend")[:structuredContent][:changed]).to eq(false)
      expect(
        UserHistory.where(
          action: UserHistory.actions[:unsuspend_user],
          target_user_id: user.id,
          acting_user_id: admin.id,
        ).count,
      ).to eq(1)
    end

    it "silences and restores a user through normal moderation behavior" do
      result = invoke("silence", actor: moderator)[:structuredContent]
      expect(user.reload.silenced?).to eq(true)
      expect(result[:user][:silenced]).to eq(true)
      expect(
        UserHistory.where(
          action: UserHistory.actions[:silence_user],
          target_user_id: user.id,
          acting_user_id: moderator.id,
        ),
      ).to exist

      expect(invoke("unsilence", actor: moderator)[:structuredContent][:changed]).to eq(true)
      expect(user.reload.silenced?).to eq(false)
      expect(invoke("unsilence", actor: moderator)[:structuredContent][:changed]).to eq(false)
      expect(
        UserHistory.where(
          action: UserHistory.actions[:unsilence_user],
          target_user_id: user.id,
          acting_user_id: moderator.id,
        ).count,
      ).to eq(1)
    end

    it "enforces staff and target permissions for every operation" do
      %w[suspend unsuspend silence unsilence].each do |operation|
        expect { invoke(operation, actor: user) }.to raise_error(Discourse::InvalidAccess)
        expect { invoke(operation, actor: moderator, username: admin.username) }.to raise_error(
          Discourse::InvalidAccess,
        )
      end
      expect(user.reload.suspended?).to eq(false)
      expect(admin.reload.silenced?).to eq(false)
    end

    it "requires confirmation for every operation" do
      %w[suspend unsuspend silence unsilence].each do |operation|
        expect { invoke(operation, confirm: false) }.to raise_error(
          DiscourseMcp::ToolError,
          I18n.t("mcp.errors.moderation_confirmation_required"),
        )
      end
      expect(user.reload.suspended?).to eq(false)
      expect(user.silenced?).to eq(false)
    end

    it "rejects invalid durations and reasons without restricting the user" do
      %w[suspend silence].each do |operation|
        [0, -1, 36_501, 1.5, "2", nil].each do |days|
          expect { invoke(operation, duration_days: days) }.to raise_error(DiscourseMcp::ToolError)
        end
        [" ", "a" * 301].each do |reason|
          expect { invoke(operation, reason: reason) }.to raise_error(DiscourseMcp::ToolError)
        end
      end
      expect(user.reload.suspended?).to eq(false)
      expect(user.silenced?).to eq(false)
    end

    it "rejects missing users and repeated restrictions rather than extending them" do
      expect { invoke("suspend", username: "nonexistent_mcp_target") }.to raise_error(
        DiscourseMcp::ToolError,
        /not found/,
      )
      %w[suspend silence].each do |operation|
        invoke(operation)
        previous = user.reload.attributes.slice("suspended_till", "silenced_till")
        expect { invoke(operation, duration_days: 10) }.to raise_error(DiscourseMcp::ToolError)
        expect(user.reload.attributes.slice("suspended_till", "silenced_till")).to eq(previous)
      end
    end
  end
end
