# frozen_string_literal: true
#
module DiscoursePostEvent
  class ChatChannelSync
    def self.sync(event, guardian: nil)
      return if !event.chat_enabled?
      if !event.chat_channel_id && guardian&.can_create_chat_channel?
        ensure_chat_channel!(event, guardian:)
      end
      sync_chat_channel_members!(event) if event.chat_channel_id
    end

    def self.sync_chat_channel_members!(event)
      missing_members_sql = <<~SQL
        SELECT user_id
        FROM discourse_post_event_invitees
        WHERE post_id = :post_id
        AND status in (:statuses)
        AND user_id NOT IN (
          SELECT user_id
          FROM user_chat_channel_memberships
          WHERE chat_channel_id = :chat_channel_id
        )
      SQL

      missing_user_ids =
        DB.query_single(
          missing_members_sql,
          post_id: event.post.id,
          statuses: [
            DiscoursePostEvent::Invitee.statuses[:going],
            DiscoursePostEvent::Invitee.statuses[:interested],
          ],
          chat_channel_id: event.chat_channel_id,
        )

      if missing_user_ids.present?
        ActiveRecord::Base.transaction do
          missing_user_ids.each do |user_id|
            event.chat_channel.user_chat_channel_memberships.create!(
              user_id:,
              chat_channel_id: event.chat_channel_id,
              following: true,
            )
          end
        end
      end
    end

    def self.ensure_chat_channel!(event, guardian:)
      name = event.name

      channel = nil
      Chat::CreateCategoryChannel.call(
        guardian:,
        params: {
          name:,
          category_id: event.post.topic.category_id,
        },
      ) do |result|
        on_success { channel = result.channel }
        on_failure { raise StandardError, result.inspect_steps }
      end

      # event creator will be a member of the channel
      event.chat_channel_id = channel.id
    end
  end
end
