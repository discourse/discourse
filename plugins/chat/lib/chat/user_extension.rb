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

    def following?(channel)
      channel_membership = channel.membership_for(self) # fixme andrei take care of N + 1
      return false if channel_membership.blank?
      return true if channel.direct_message_channel?
      channel_membership.following
    end

    def uses_chat?
      user_option.chat_enabled
    end
  end
end
