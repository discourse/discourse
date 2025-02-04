# frozen_string_literal: true

module Jobs
  module Chat
    class NotifyMentioned < ::Jobs::Base
      def execute(args = {})
        @chat_message =
          ::Chat::Message.includes(:user, :revisions, chat_channel: :chatable).find_by(
            id: args[:chat_message_id],
          )
        if @chat_message.nil? ||
             @chat_message.revisions.where("created_at > ?", args[:timestamp]).any?
          return
        end

        @creator = @chat_message.user
        @chat_channel = @chat_message.chat_channel
        @is_direct_message_channel = @chat_channel.direct_message_channel?
        @already_notified_user_ids = args[:already_notified_user_ids] || []
        user_ids_to_notify = args[:to_notify_ids_map] || {}
        user_ids_to_notify.each { |mention_type, ids| process_mentions(ids, mention_type.to_sym) }
      end

      private

      def get_memberships(user_ids)
        query =
          ::Chat::UserChatChannelMembership.includes(:user).where(
            user_id: (user_ids - @already_notified_user_ids),
            chat_channel_id: @chat_message.chat_channel_id,
          )
        query = query.where(following: true) if @chat_channel.public_channel?
        query
      end

      def build_data_for(membership, identifier_type:)
        data = {
          chat_message_id: @chat_message.id,
          chat_channel_id: @chat_channel.id,
          mentioned_by_username: @creator.username,
          is_direct_message_channel: @is_direct_message_channel,
        }

        data[:chat_thread_id] = @chat_message.thread_id if @chat_message.in_thread?

        if !@is_direct_message_channel
          data[:chat_channel_title] = @chat_channel.title(membership.user)
          data[:chat_channel_slug] = @chat_channel.slug
        end

        return data if identifier_type == :direct_mentions

        case identifier_type
        when :here_mentions
          data[:identifier] = "here"
        when :global_mentions
          data[:identifier] = "all"
        else
          data[:identifier] = identifier_type if identifier_type
          data[:is_group_mention] = true
        end

        data
      end

      def build_payload_for(membership, identifier_type:)
        post_url =
          if @chat_message.in_thread?
            @chat_message.thread.relative_url
          else
            "#{@chat_channel.relative_url}/#{@chat_message.id}"
          end

        payload = {
          notification_type: ::Notification.types[:chat_mention],
          username: @creator.username,
          tag: ::Chat::Notifier.push_notification_tag(:mention, @chat_channel.id),
          excerpt: @chat_message.push_notification_excerpt,
          post_url: post_url,
          channel_id: @chat_channel.id,
          is_direct_message_channel: @is_direct_message_channel,
        }

        translation_prefix =
          (
            if @chat_channel.direct_message_channel?
              "discourse_push_notifications.popup.direct_message_chat_mention"
            else
              "discourse_push_notifications.popup.chat_mention"
            end
          )

        translation_suffix = identifier_type == :direct_mentions ? "direct" : "other_type"
        identifier_text =
          case identifier_type
          when :here_mentions
            "@here"
          when :global_mentions
            "@all"
          when :direct_mentions
            ""
          else
            "@#{identifier_type}"
          end

        payload[:translated_title] = ::I18n.t(
          "#{translation_prefix}.#{translation_suffix}",
          username: @creator.username,
          identifier: identifier_text,
          channel: @chat_channel.title(membership.user),
        )

        payload
      end

      def create_notification!(membership, mention, mention_type)
        notification_data = build_data_for(membership, identifier_type: mention_type)
        is_read = ::Chat::Notifier.user_has_seen_message?(membership, @chat_message.id)
        notification =
          ::Notification.create!(
            notification_type: ::Notification.types[:chat_mention],
            user_id: membership.user_id,
            high_priority: true,
            data: notification_data.to_json,
            read: is_read,
          )

        mention.notifications << notification
      end

      def send_notifications(membership, mention_type)
        payload = build_payload_for(membership, identifier_type: mention_type)

        if !membership.notifications_never? && !membership.muted?
          ::MessageBus.publish(
            "/chat/notification-alert/#{membership.user_id}",
            payload,
            user_ids: [membership.user_id],
          )
          ::PostAlerter.push_notification(membership.user, payload)
        end
      end

      def process_mentions(user_ids, mention_type)
        memberships = get_memberships(user_ids)

        memberships.each do |membership|
          mention = find_mention(@chat_message, mention_type, membership.user.id)
          if mention.present?
            create_notification!(membership, mention, mention_type)
            send_notifications(membership, mention_type)
          end
        end
      end

      def find_mention(chat_message, mention_type, user_id)
        mention_klass = resolve_mention_klass(mention_type)

        target_id = nil
        if mention_klass == ::Chat::UserMention
          target_id = user_id
        elsif mention_klass == ::Chat::GroupMention
          begin
            target_id = Group.where("LOWER(name) = ?", "#{mention_type}").pick(:id)
          rescue => e
            Discourse.warn_exception(e, message: "Mentioned group doesn't exist")
          end
        end

        mention_klass.find_by(chat_message: chat_message, target_id: target_id)
      end

      def resolve_mention_klass(mention_type)
        case mention_type
        when :global_mentions
          ::Chat::AllMention
        when :here_mentions
          ::Chat::HereMention
        when :direct_mentions
          ::Chat::UserMention
        else
          ::Chat::GroupMention
        end
      end
    end
  end
end
