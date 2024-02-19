# frozen_string_literal: true

module Jobs
  module Chat
    class NotifyMentioned < ::Jobs::Base
      # fixme andrei preload user on mentions
      # fixme preload chat_channel and other stuff?
      def execute(args)
        @message = ::Chat::Message.find(args[:message_id])
        parsed_mentions = @message.parsed_mentions

        parsed_mentions.direct_mentions.each do |user|
          mention = @message.chat_mentions.where(target_id: user.id).first
          create_notification!(mention, user)
          send_desktop_notification(mention, user)
        end

        parsed_mentions.global_mentions.each do |user|
          create_notification!(@message.all_mention, user)
          send_desktop_notification(mention, user)
        end

        parsed_mentions.here_mentions.each do |user|
          create_notification!(@message.here_mention, user)
          send_desktop_notification(mention, user)
        end
      end

      private

      def create_notification!(mention, mentioned_user)
        # fixme andrei shouldn't this be already excluded from parsed_mentions?
        return if mentioned_user.id == @message.user_id

        notification =
          ::Notification.create!(
            notification_type: ::Notification.types[:chat_mention],
            user_id: mentioned_user.id,
            high_priority: true,
            data: mention.notification_data,
          )
        mention.notifications << notification
      end

      def send_desktop_notification(mention, mentioned_user)
        payload = build_payload_for(mention, mentioned_user)

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

      def build_payload_for(chat_mention, mentioned_user)
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
    end
  end
end
