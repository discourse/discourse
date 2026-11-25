# frozen_string_literal: true

module DiscourseWorkflows
  class ChatConversation::Run
    include Service::Base

    params do
      attribute :message_id, :integer

      validates :message_id, presence: true
    end

    model :message
    model :conversation
    model :trigger
    step :execute

    private

    def fetch_message(params:)
      ::Chat::Message.find_by(id: params.message_id)
    end

    def fetch_conversation(message:)
      ChatConversation.find_by(channel_id: message.chat_channel_id, user_id: message.user_id)
    end

    def fetch_trigger(conversation:)
      conversation.trigger
    end

    def execute(message:, conversation:, trigger:)
      TriggerDispatcher.execute(
        trigger,
        trigger_data: trigger.node_type.new(message, conversation).output,
        user: message.user,
        # Duplicate and redelivered jobs share this key, so the graph runs once per message.
        job_id: "chat_conversation:#{message.id}",
      )
    end
  end
end
