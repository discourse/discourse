# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::ChatToolApproval do
  fab!(:admin)
  fab!(:ai_agent)
  fab!(:target_user, :user)
  fab!(:non_staff) { Fabricate(:user, trust_level: TrustLevel[1]) }

  let(:bot_user) { Discourse.system_user }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    SiteSetting.chat_enabled = true
  end

  fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [admin, target_user]) }

  def create_reviewable(username: target_user.username)
    action =
      AiToolAction.create!(
        tool_name: "suspend_user",
        tool_parameters: {
          username: username,
          duration_days: 3,
          reason: "spam",
        },
        ai_agent: ai_agent,
        bot_user_id: bot_user.id,
      )
    reviewable =
      ReviewableAiToolAction.needs_review!(
        target: action,
        created_by: bot_user,
        reviewable_by_moderator: true,
        payload: {
          agent_name: "Test",
          reason: "spam",
        },
      )
    reviewable.add_score(
      Discourse.system_user,
      ReviewableScore.types[:needs_approval],
      force_review: true,
    )
    reviewable
  end

  def message_for(reviewable)
    message = Fabricate(:chat_message, chat_channel: dm_channel, user: bot_user)
    message.update!(blocks: DiscourseAi::AiBot::ChatToolApproval.pending_blocks(reviewable.id))
    message
  end

  def interaction_for(reviewable, user:, action: "approve", message: nil)
    Chat::MessageInteraction.new(
      user: user,
      message: message || message_for(reviewable),
      action: {
        "action_id" => DiscourseAi::AiBot::ChatToolApproval.build_action_id(action, reviewable.id),
      },
    )
  end

  describe ".build_action_id / .parse_action_id" do
    it "round-trips a valid action id" do
      id = described_class.build_action_id("approve", 42)
      expect(described_class.parse_action_id(id)).to eq(action: "approve", reviewable_id: 42)
    end

    it "rejects foreign, unknown, and malformed ids" do
      expect(described_class.parse_action_id("other::approve::1")).to be_nil
      expect(described_class.parse_action_id("ai_tool_approval::destroy::1")).to be_nil
      expect(described_class.parse_action_id("ai_tool_approval::approve::0")).to be_nil
      expect(described_class.parse_action_id(nil)).to be_nil
    end
  end

  describe ".pending_blocks" do
    it "builds an actions block with approve/reject buttons carrying the reviewable id" do
      blocks = described_class.pending_blocks(7)

      expect(blocks.first[:type]).to eq("actions")
      expect(blocks.first[:elements].map { |e| e[:action_id] }).to contain_exactly(
        "ai_tool_approval::approve::7",
        "ai_tool_approval::reject::7",
      )
    end
  end

  describe ".handle_interaction" do
    it "approves: suspends the user (credited to the approver) and resolves the message" do
      reviewable = create_reviewable
      message = message_for(reviewable)

      described_class.handle_interaction(
        interaction_for(reviewable, user: admin, action: "approve", message: message),
      )

      expect(target_user.reload.suspended?).to eq(true)

      message.reload
      expect(message.blocks).to be_blank
      expect(message.message).to include(admin.username)

      history = UserHistory.where(action: UserHistory.actions[:suspend_user]).last
      expect(history.acting_user_id).to eq(admin.id)
      expect(history.target_user_id).to eq(target_user.id)
    end

    it "rejects: resolves the message without suspending" do
      reviewable = create_reviewable
      message = message_for(reviewable)

      described_class.handle_interaction(
        interaction_for(reviewable, user: admin, action: "reject", message: message),
      )

      expect(target_user.reload.suspended?).to eq(false)
      reviewable.reload
      expect(reviewable).not_to be_pending
      expect(reviewable.status.to_s).to eq("rejected")
      expect(message.reload.blocks).to be_blank
    end

    it "does nothing for a user who cannot see the review queue" do
      reviewable = create_reviewable
      message = message_for(reviewable)

      described_class.handle_interaction(
        interaction_for(reviewable, user: non_staff, message: message),
      )

      expect(target_user.reload.suspended?).to eq(false)
      expect(reviewable.reload).to be_pending
      expect(message.reload.blocks).to be_present
    end

    it "ignores foreign action ids" do
      reviewable = create_reviewable
      message = message_for(reviewable)
      interaction =
        Chat::MessageInteraction.new(
          user: admin,
          message: message,
          action: {
            "action_id" => "some_other_plugin::approve::#{reviewable.id}",
          },
        )

      described_class.handle_interaction(interaction)

      expect(reviewable.reload).to be_pending
      expect(target_user.reload.suspended?).to eq(false)
    end

    it "does nothing for a reviewable that is no longer pending" do
      reviewable = create_reviewable
      reviewable.perform(admin, :reject)

      expect {
        described_class.handle_interaction(interaction_for(reviewable, user: admin))
      }.not_to change { target_user.reload.suspended? }
    end

    it "keeps the buttons and surfaces the real reason when the action fails" do
      reviewable = create_reviewable(username: "does_not_exist")
      message = message_for(reviewable)

      described_class.handle_interaction(
        interaction_for(reviewable, user: admin, action: "approve", message: message),
      )

      expect(reviewable.reload).to be_pending
      message.reload
      expect(message.blocks).to be_present
      # the localized tool error, not the raw "ai_tool_action_execution_error" type
      expect(message.message).to include(
        I18n.t("discourse_ai.ai_bot.suspend_user.errors.not_found"),
      )
      expect(message.message).not_to include("ai_tool_action_execution_error")
    end
  end

  describe "end-to-end via Chat::CreateMessageInteraction" do
    it "approves through the real interaction service (transaction + event)" do
      reviewable = create_reviewable
      message = message_for(reviewable)

      result =
        Chat::CreateMessageInteraction.call(
          params: {
            message_id: message.id,
            channel_id: dm_channel.id,
            action_id:
              DiscourseAi::AiBot::ChatToolApproval.build_action_id("approve", reviewable.id),
          },
          guardian: Guardian.new(admin),
        )

      expect(result.success?).to eq(true)
      expect(target_user.reload.suspended?).to eq(true)
      expect(reviewable.reload).not_to be_pending
      expect(message.reload.blocks).to be_blank
    end
  end
end
