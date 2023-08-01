# frozen_string_literal: true

module Chat
  class ChatableUserSerializer < ::Chat::UserWithCustomFieldsAndStatusSerializer
    attributes :can_chat, :has_chat_enabled

    def can_chat
      SiteSetting.chat_enabled && scope.can_chat?
    end

    def has_chat_enabled
      can_chat && object.user_option&.chat_enabled
    end
  end
end
