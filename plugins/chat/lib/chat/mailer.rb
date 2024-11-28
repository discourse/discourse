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
              type: "chat_summary",
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
          "JOIN group_users gu ON gu.user_id = u.id AND gu.group_id IN (#{Chat.allowed_group_ids.join(",")})"
        end

      DB.query_single <<~SQL
        WITH eligible_users AS (
          SELECT DISTINCT u.id, uo.allow_private_messages
          FROM users u
          JOIN user_options uo ON uo.user_id = u.id 
          #{groups_join_sql}
          WHERE u.last_seen_at < now() - interval '15 minutes'
          AND uo.chat_enabled 
          AND uo.chat_email_frequency = #{UserOption.chat_email_frequencies[:when_away]}
          AND uo.email_level <> #{UserOption.email_level_types[:never]}
        ), channel_messages AS (
            SELECT DISTINCT ON (chat_channel_id) chat_channel_id, cm.id AS first_unread_id, user_id AS sender_id
            FROM chat_messages cm
            JOIN users sender ON sender.id = cm.user_id
            WHERE cm.created_at > now() - interval '7 days'
            AND cm.deleted_at IS NULL 
            AND NOT cm.created_by_sdk
            ORDER BY chat_channel_id, cm.id
        )
        SELECT DISTINCT uccm.user_id
        FROM user_chat_channel_memberships uccm 
        JOIN chat_channels cc ON cc.id = uccm.chat_channel_id AND cc.deleted_at IS NULL
        JOIN channel_messages cm ON cm.chat_channel_id = cc.id AND cm.sender_id <> uccm.user_id
        JOIN eligible_users eu ON eu.id = uccm.user_id
        LEFT JOIN chat_mentions mn ON mn.chat_message_id = cm.first_unread_id
        LEFT JOIN chat_mention_notifications cmn ON cmn.chat_mention_id = mn.id
        LEFT JOIN notifications n ON n.id = cmn.notification_id AND n.user_id = uccm.user_id
        WHERE NOT uccm.muted 
        AND (uccm.last_read_message_id IS NULL OR cm.first_unread_id > uccm.last_read_message_id)
        AND (uccm.last_unread_mention_when_emailed_id IS NULL OR cm.first_unread_id > uccm.last_unread_mention_when_emailed_id)
        AND (
            (cc.chatable_type = 'DirectMessage' AND eu.allow_private_messages) OR 
            (cc.chatable_type = 'Category' AND uccm.following AND (n.id IS NULL OR NOT n.read))
        )
      SQL
    end
  end
end
