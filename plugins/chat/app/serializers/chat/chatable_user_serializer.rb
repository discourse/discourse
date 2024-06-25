# frozen_string_literal: true

module Chat
  class ChatableUserSerializer < UserWithCustomFieldsSerializer
    attributes :can_chat, :has_chat_enabled

    def can_chat
      SiteSetting.chat_enabled && object.guardian.can_chat? && scope.can_create_direct_message?
    end

    def has_chat_enabled
      can_chat && object.user_option&.chat_enabled
    end
  end
end
