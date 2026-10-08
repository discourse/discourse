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

  describe ".format_value" do
    it "renders multiline markup and backticks as code, and makes empty values explicit" do
      value = "```\n<script>alert('test')</script>\n```"
      cooked = Nokogiri::HTML5.fragment(Chat::Message.cook(described_class.format_value(value)))

      expect(cooked.at_css("pre code").text.chomp).to eq(value)
      expect(cooked.css("script")).to be_empty
      empty = Nokogiri::HTML5.fragment(Chat::Message.cook(described_class.format_value("")))
      expect(empty.at_css("code").text).to eq(
        I18n.t("discourse_ai.ai_bot.chat_tool_approval.empty_value"),
      )
    end
  end

  describe ".transcript_text" do
    it "renders the proposal, and later its outcome, from the card" do
      message =
        Fabricate(
          :chat_message,
          chat_channel: dm_channel,
          user: bot_user,
          message: "Changing a setting",
        )
      message.update!(
        blocks:
          described_class.pending_blocks(
            7,
            info: {
              summary: "Changing site setting: title",
              changes: [{ label: "Changing value:", before: "Old", after: "New" }],
              details: message.message,
              question: "Do you want to make this change?",
              parameters: [],
            },
          ),
      )

      expect(described_class.transcript_text(message)).to eq(
        [
          "Changing site setting: title",
          "Changing value: Old → New",
          I18n.t("discourse_ai.ai_bot.tool_pending_approval"),
        ].join("\n"),
      )

      described_class.resolve_message!(message, "Approved by @#{admin.username}.")

      expect(described_class.transcript_text(message.reload)).to eq(
        [
          "Changing site setting: title",
          "Changing value: Old → New",
          "Approved by @#{admin.username}.",
        ].join("\n"),
      )
      expect(
        described_class.transcript_text(Fabricate(:chat_message, message: "plain reply")),
      ).to eq("plain reply")
    end
  end

  describe ".pending_blocks" do
    it "truncates oversized preview values to the schema limit" do
      limit = Chat::Schemas::CONFIRMATION_VALUE_MAX_LENGTH
      long = "x" * (limit + 10)
      blocks =
        described_class.pending_blocks(
          7,
          info: {
            summary: "Editing post",
            question: "Do you want to make this change?",
            parameters: [{ label: "raw", value: long }],
            changes: [{ label: "Changing content:", before: long, after: "short" }],
          },
        )

      expect(JSONSchemer.schema(Chat::Schemas::MessageBlocks).valid?(blocks.as_json)).to eq(true)
      expect(blocks.first[:changes].first[:before].length).to eq(limit)
      expect(blocks.first[:parameters].first[:value]).to end_with("...")
    end

    it "builds a confirmation card with Yes and No actions" do
      blocks =
        described_class.pending_blocks(
          7,
          info: {
            summary: "Edit category",
            details: "Changing name",
            question: "Do you want to make this change?",
            parameters: [{ label: "name", value: "Wind & Rain" }],
          },
        )

      expect(JSONSchemer.schema(Chat::Schemas::MessageBlocks).valid?(blocks.as_json)).to eq(true)
      expect(blocks.first).to include(type: "confirmation", title: "Edit category")
      expect(blocks.first[:elements].map { |element| element.dig(:text, :text) }).to eq(%w[Yes No])
    end

    it "builds an actions block with approve/reject buttons carrying the reviewable id" do
      blocks = described_class.pending_blocks(7)

      expect(blocks.first[:type]).to eq("actions")
      expect(blocks.first[:elements].map { |e| e[:action_id] }).to contain_exactly(
        "ai_tool_approval::approve::7",
        "ai_tool_approval::reject::7",
      )
    end
  end

  describe ".handle_interaction for a tag rename" do
    it "keeps the renamed tag badge and the original diff after approval" do
      SiteSetting.tagging_enabled = true
      tag = Fabricate(:tag, name: "old-name")
      action =
        AiToolAction.create!(
          tool_name: "edit_tag",
          tool_parameters: {
            name: tag.name,
            new_name: "Neat Stuff!",
            reason: "Rebranding",
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
            reason: "Rebranding",
          },
        )
      reviewable.add_score(
        Discourse.system_user,
        ReviewableScore.types[:needs_approval],
        force_review: true,
      )
      message = message_for(reviewable)
      changes = [{ label: "Changing name:", before: "old-name", after: "neat-stuff" }]
      message.update!(
        blocks:
          described_class.pending_blocks(
            reviewable.id,
            info: {
              summary: "Editing tag: #old-name::tag",
              question: "Do you want to make this change?",
              parameters: [],
              changes: changes,
            },
          ),
      )

      described_class.handle_interaction(interaction_for(reviewable, user: admin, message: message))

      expect(reviewable.reload).to be_approved
      expect(tag.reload.name).to eq("neat-stuff")
      card = message.reload.blocks.first
      expect(card["changes"]).to eq(changes.as_json)
      title = Nokogiri::HTML5.fragment(Chat::Message.cook(card["title"], user_id: admin.id))
      expect(title.at_css("a.hashtag-cooked")["data-id"]).to eq(tag.id.to_s)
    end
  end

  describe ".resolve_message!" do
    it "preserves the card and proposed values while replacing the actions with the outcome" do
      message =
        Fabricate(
          :chat_message,
          chat_channel: dm_channel,
          user: bot_user,
          message: "Changing a setting",
        )
      message.update!(
        blocks:
          described_class.pending_blocks(
            7,
            info: {
              summary: "Change site setting",
              changes: [{ label: "Changing name:", before: "Old", after: "New" }],
              details: message.message,
              question: "Do you want to make this change?",
              parameters: [{ label: "value", value: "<new `value`>" }],
            },
          ),
      )

      described_class.append_error!(message, "Try again")
      expect(message.reload.blocks.first["error"]).to eq("Try again")
      described_class.resolve_message!(message, "Approved")

      card = message.reload.blocks.first
      expect(card).to include(
        "title" => "Change site setting",
        "status" => "Approved",
        "changes" => [{ "label" => "Changing name:", "before" => "Old", "after" => "New" }],
        "elements" => [],
        "parameters" => [{ "label" => "value", "value" => "<new `value`>" }],
      )
      expect(card).not_to have_key("error")
      expect(message.message).to eq("Changing a setting")
      expect(JSONSchemer.schema(Chat::Schemas::MessageBlocks).valid?(message.blocks)).to eq(true)
    end
  end

  describe ".handle_interaction" do
    it "accepts a main-chat approval for a thread's original message" do
      reviewable = create_reviewable
      thread = Fabricate(:chat_thread, channel: dm_channel, original_message_user: admin)
      reviewable.update!(
        payload: reviewable.payload.merge("chat_message_id" => thread.original_message_id),
      )
      message = message_for(reviewable)

      described_class.handle_interaction(
        interaction_for(reviewable, user: admin, action: "reject", message: message),
      )

      expect(reviewable.reload).to be_rejected
    end

    it "rejects a main-chat approval for an actual thread reply" do
      reviewable = create_reviewable
      thread = Fabricate(:chat_thread, channel: dm_channel, original_message_user: admin)
      source = Fabricate(:chat_message, chat_channel: dm_channel, thread: thread, user: admin)
      reviewable.update!(payload: reviewable.payload.merge("chat_message_id" => source.id))
      message = message_for(reviewable)

      described_class.handle_interaction(
        interaction_for(reviewable, user: admin, action: "reject", message: message),
      )

      expect(reviewable.reload).to be_pending
      expect(message.reload.blocks).to be_present
    end

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

    it "rejects an approval attached to a human message" do
      reviewable = create_reviewable
      message = message_for(reviewable)
      message.update!(user: admin)

      described_class.handle_interaction(interaction_for(reviewable, user: admin, message: message))

      expect(reviewable.reload).to be_pending
      expect(target_user.reload.suspended?).to eq(false)
      expect(reviewable.payload["continuation"]).to be_nil
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
      expect(reviewable.payload["continuation"]).to include("chat_message_id" => message.id)
      expect(Jobs::ResumeAiToolApproval.jobs.last["args"].first).to include(
        "reviewable_id" => reviewable.id,
      )
    end
  end
end
