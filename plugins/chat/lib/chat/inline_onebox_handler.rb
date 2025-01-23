# frozen_string_literal: true

module Chat
  class InlineOneboxHandler
    def self.handle(url, route)
      if route[:message_id].present?
        message = Chat::Message.find_by(id: route[:message_id])
        return if !message

        chat_channel = message.chat_channel
        user = message.user
        return if !chat_channel || !user

        title =
          I18n.t(
            "chat.onebox.inline_to_message",
            message_id: message.id,
            chat_channel: chat_channel.name,
            username: user.username,
          )
      else
        chat_channel = Chat::Channel.find_by(id: route[:channel_id])
        return if !chat_channel

        if route[:thread_id].present?
          thread = Chat::Thread.find_by(id: route[:thread_id])
          return if !thread

          title =
            if thread.title.present?
              I18n.t(
                "chat.onebox.inline_to_thread",
                chat_channel: chat_channel.name,
                thread_title: thread.title,
              )
            else
              I18n.t("chat.onebox.inline_to_thread_no_title", chat_channel: chat_channel.name)
            end
        else
          title =
            if chat_channel.name.present?
              I18n.t("chat.onebox.inline_to_channel", chat_channel: chat_channel.name)
            end
        end
      end

      return if !Guardian.new.can_preview_chat_channel?(chat_channel)

      { url: url, title: title }
    end
  end
end
