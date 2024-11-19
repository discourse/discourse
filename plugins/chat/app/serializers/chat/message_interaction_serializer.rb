# frozen_string_literal: true

module Chat
  class MessageInteractionSerializer < ::ApplicationSerializer
    attributes :user, :channel, :message, :action

    def user
      { id: object.user.id, username: object.user.username }
    end

    def channel
      { id: object.message.chat_channel.id, title: object.message.chat_channel.title }
    end

    def message
      { id: object.message.id, text: object.message.message, user_id: object.message.user.id }
    end
  end
end
