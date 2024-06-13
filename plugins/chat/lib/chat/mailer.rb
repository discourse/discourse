# frozen_string_literal: true

module Chat
  class Mailer
    def self.send_unread_mentions_summary
      return unless SiteSetting.chat_enabled

      User
        .real
        .activated
        .not_staged
        .not_suspended
        .where(id: users_with_unreads)
        .find_each do |user|
          if DiscoursePluginRegistry.apply_modifier(:chat_mailer_send_summary_to_user, true, user)
            Jobs.enqueue(
              :user_email,
              type: :chat_summary,
              user_id: user.id,
              force_respect_seen_recently: true,
            )
          end
        end
    end

    private

    def self.users_with_unreads
      groups_join_sql =
        if Chat.allowed_group_ids.include?(Group::AUTO_GROUPS[:everyone])
          ""
        else
          "JOIN group_users ON group_users.user_id = users.id AND group_users.group_id IN (#{Chat.allowed_group_ids.join(",")})"
        end

      DB.query_single <<~SQL
        SELECT uccm.user_id
        FROM user_chat_channel_memberships uccm
        JOIN users ON users.id = uccm.user_id
        JOIN user_options ON user_options.user_id = users.id
        #{groups_join_sql}
        JOIN chat_channels ON chat_channels.id = uccm.chat_channel_id
        JOIN chat_messages ON chat_messages.chat_channel_id = chat_channels.id
        JOIN users sender ON sender.id = chat_messages.user_id
        LEFT JOIN chat_mentions ON chat_mentions.chat_message_id = chat_messages.id
        LEFT JOIN chat_mention_notifications cmn ON cmn.chat_mention_id = chat_mentions.id
        LEFT JOIN notifications ON notifications.id = cmn.notification_id AND notifications.user_id = uccm.user_id
        WHERE NOT uccm.muted
        AND (uccm.last_read_message_id IS NULL OR uccm.last_read_message_id < chat_messages.id)
        AND (uccm.last_unread_mention_when_emailed_id IS NULL OR uccm.last_unread_mention_when_emailed_id < chat_messages.id)
        AND users.last_seen_at < now() - interval '15 minutes'
        AND user_options.chat_enabled
        AND user_options.chat_email_frequency = #{UserOption.chat_email_frequencies[:when_away]}
        AND user_options.email_level <> #{UserOption.email_level_types[:never]}
        AND chat_channels.deleted_at IS NULL
        AND chat_messages.deleted_at IS NULL
        AND chat_messages.created_at > now() - interval '1 week'
        AND chat_messages.user_id <> users.id
        AND (
          (chat_channels.chatable_type = 'DirectMessage' AND user_options.allow_private_messages) OR
          (chat_channels.chatable_type = 'Category' AND uccm.following AND NOT notifications.read)
        )
        GROUP BY uccm.user_id
      SQL
    end
  end
end
