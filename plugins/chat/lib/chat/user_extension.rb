# frozen_string_literal: true

module Chat
  module UserExtension
    extend ActiveSupport::Concern

    prepended do
      has_many :user_chat_channel_memberships,
               class_name: "Chat::UserChatChannelMembership",
               dependent: :destroy
      has_many :chat_message_reactions, class_name: "Chat::MessageReaction", dependent: :destroy
      has_many :chat_mentions, class_name: "Chat::Mention"
    end
  end
end
