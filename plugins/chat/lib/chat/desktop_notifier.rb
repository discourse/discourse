# frozen_string_literal: true

module Chat
  class DesktopNotifier
    def self.notify_mentioned(mention, mentioned_user)
      payload = payload(mention, mentioned_user)

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

    private

    # fixme andrei find a better place for it
    def self.payload(chat_mention, mentioned_user)
      message = chat_mention.chat_message
      channel = message.chat_channel

      post_url =
        if message.in_thread?
          message.thread.relative_url
        else
          "#{channel.relative_url}/#{message.id}"
        end

      payload = {
        notification_type: ::Notification.types[:chat_mention],
        username: message.user.username,
        tag: ::Chat::Notifier.push_notification_tag(:mention, channel.id),
        excerpt: message.push_notification_excerpt,
        post_url: post_url,
      }

      translation_prefix =
        (
          if channel.direct_message_channel?
            "discourse_push_notifications.popup.direct_message_chat_mention"
          else
            "discourse_push_notifications.popup.chat_mention"
          end
        )

      translation_suffix = chat_mention.is_a?(::Chat::UserMention) ? "direct" : "other_type"

      identifier_text =
        case chat_mention
        when ::Chat::HereMention
          "@here"
        when ::Chat::AllMention
          "@all"
        when ::Chat::UserMention
          ""
        when ::Chat::GroupMention
          "@#{chat_mention.group.name}"
        else
          raise "Unknown mention type"
        end

      payload[:translated_title] = ::I18n.t(
        "#{translation_prefix}.#{translation_suffix}",
        username: message.user.username,
        identifier: identifier_text,
        channel: channel.title(mentioned_user),
      )

      payload
    end

    private_class_method :payload
  end
end
