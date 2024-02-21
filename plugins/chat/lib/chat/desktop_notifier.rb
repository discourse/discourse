# frozen_string_literal: true

module Chat
  class DesktopNotifier
    def self.notify_mentioned(mention, mentioned_user)
      payload = Chat::Mention.notification_payload(mention, mentioned_user)

      # fixme andrei take care of N + 1
      mentioned_user_membership = mention.chat_message.chat_channel.membership_for(mentioned_user)

      if !mentioned_user_membership.desktop_notifications_never? &&
           !mentioned_user_membership.muted?
        ::MessageBus.publish(
          "/chat/notification-alert/#{mentioned_user.id}",
          payload,
          user_ids: [mentioned_user.id],
        )
      end
    end
  end
end
