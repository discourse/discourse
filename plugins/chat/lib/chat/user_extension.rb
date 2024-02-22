# frozen_string_literal: true

module Chat
  module UserExtension
    extend ActiveSupport::Concern

    prepended do
      has_many :user_chat_channel_memberships,
               class_name: "Chat::UserChatChannelMembership",
               dependent: :destroy
      has_many :user_chat_thread_memberships,
               class_name: "Chat::UserChatThreadMembership",
               dependent: :destroy
      has_many :chat_message_reactions, class_name: "Chat::MessageReaction", dependent: :destroy
      has_many :chat_mentions, class_name: "Chat::UserMention", foreign_key: "target_id"
      has_many :direct_message_users, class_name: "Chat::DirectMessageUser"
      has_many :direct_messages, through: :direct_message_users, class_name: "Chat::DirectMessage"
    end
  end
end
