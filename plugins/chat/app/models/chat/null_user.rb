# frozen_string_literal: true

module Chat
  class NullUser < User
    def username
      I18n.t("chat.deleted_chat_username")
    end

    def avatar_template
      "/plugins/chat/images/deleted-chat-user-avatar.png"
    end

    def bot?
      false
    end
  end
end
