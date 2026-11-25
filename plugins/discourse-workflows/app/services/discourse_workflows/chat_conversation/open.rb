# frozen_string_literal: true

module DiscourseWorkflows
  class ChatConversation::Open
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :node_id, :string
      attribute :draft, :boolean, default: false

      validates :workflow_id, :node_id, presence: true
    end

    policy :can_chat
    model :trigger
    model :bot

    transaction do
      model :channel, :create_channel
      step :bind
    end

    step :post_welcome_message

    private

    def can_chat(guardian:)
      ChatConversation.chat_available? && guardian.can_chat?
    end

    def fetch_trigger(params:, guardian:)
      ChatConversation.trigger_for(
        guardian.user,
        workflow_id: params.workflow_id,
        node_id: params.node_id,
        draft: params.draft,
      )
    end

    def fetch_bot(trigger:)
      ChatConversation.bots.find_by(
        id: trigger.parameters["chat_bot_id"].presence || Discourse::SYSTEM_USER_ID,
      )
    end

    def create_channel(guardian:, trigger:, bot:)
      title = trigger.parameters["chat_title"].presence || trigger.workflow_name

      # A named DM is always a new group DM, so every launch gets its own conversation.
      ::Chat::CreateDirectMessageChannel.call(
        guardian:,
        params: {
          name: title.truncate(SiteSetting.max_topic_title_length),
          target_usernames: [bot.username],
        },
      ) { on_success { |channel:| channel } }
    end

    def bind(guardian:, trigger:, bot:, channel:)
      ChatConversation.create!(
        channel_id: channel.id,
        user: guardian.user,
        bot_user: bot,
        workflow_id: trigger.workflow_id,
        trigger_node_id: trigger.trigger_node_id,
        draft: trigger.draft?,
      )
    end

    def post_welcome_message(trigger:, bot:, channel:)
      notice = I18n.t("discourse_workflows.workflow_chat.draft_notice") if trigger.draft?
      message = [notice, trigger.parameters["welcome_message"]].compact_blank.join("\n\n")

      if message.present?
        ::ChatSDK::Message.create(
          raw: message,
          channel_id: channel.id,
          guardian: bot.guardian,
          enforce_membership: true,
        )
      end
    end
  end
end
