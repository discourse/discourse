# frozen_string_literal: true

module Chat
  module UserNotificationsExtension
    def chat_summary(user, _ = nil)
      guardian = Guardian.new(user)
      return unless guardian.can_chat?

      # TODO: handle muted & silenced users ?

      # ensures these haven't since the job was enqueued
      return if user.last_seen_at > 15.minutes.ago
      return if user.user_option.send_chat_email_never?
      return if user.user_option.email_level == UserOption.email_level_types[:never]

      unread_mentions = DB.query_array <<~SQL
        WITH unread_mentions AS (
          SELECT uccm.id membership_id, uccm.chat_channel_id, MIN(chat_messages.id) first_chat_message_id, MAX(chat_messages.id) last_chat_message_id
          FROM user_chat_channel_memberships uccm
          JOIN chat_channels ON chat_channels.id = uccm.chat_channel_id
          JOIN chat_messages ON chat_messages.chat_channel_id = chat_channels.id
          JOIN chat_mentions ON chat_mentions.chat_message_id = chat_messages.id
          JOIN chat_mention_notifications cmn ON cmn.chat_mention_id = chat_mentions.id
          JOIN notifications ON notifications.id = cmn.notification_id
          JOIN users ON users.id = chat_messages.user_id
          WHERE uccm.user_id = #{user.id}
          AND NOT uccm.muted
          AND uccm.following
          AND chat_channels.deleted_at IS NULL
          AND chat_channels.chatable_type = 'Category'
          AND chat_messages.deleted_at IS NULL
          AND chat_messages.user_id != uccm.user_id
          AND chat_messages.created_at > now() - interval '1 week'
          AND (uccm.last_read_message_id IS NULL OR uccm.last_read_message_id < chat_messages.id)
          AND (uccm.last_unread_mention_when_emailed_id IS NULL OR uccm.last_unread_mention_when_emailed_id < chat_messages.id)
          AND NOT notifications.read
          GROUP BY uccm.id
        )
        UPDATE user_chat_channel_memberships uccm
        SET last_unread_mention_when_emailed_id = um.last_chat_message_id
        FROM unread_mentions um
        WHERE uccm.id = um.membership_id
        AND uccm.user_id = #{user.id}
        RETURNING um.membership_id, um.chat_channel_id, um.first_chat_message_id
      SQL

      unread_messages = DB.query_array <<~SQL
        WITH unread_messages AS (
          SELECT uccm.id membership_id, uccm.chat_channel_id, MIN(chat_messages.id) first_chat_message_id, MAX(chat_messages.id) last_chat_message_id
          FROM user_chat_channel_memberships uccm
          JOIN chat_channels ON chat_channels.id = uccm.chat_channel_id
          JOIN chat_messages ON chat_messages.chat_channel_id = chat_channels.id
          JOIN users ON users.id = chat_messages.user_id
          WHERE uccm.user_id = #{user.id}
          AND NOT uccm.muted
          AND chat_channels.deleted_at IS NULL
          AND chat_channels.chatable_type = 'DirectMessage'
          AND chat_messages.deleted_at IS NULL
          AND chat_messages.user_id != uccm.user_id
          AND chat_messages.created_at > now() - interval '1 week'
          AND (uccm.last_read_message_id IS NULL OR uccm.last_read_message_id < chat_messages.id)
          AND (uccm.last_unread_mention_when_emailed_id IS NULL OR uccm.last_unread_mention_when_emailed_id < chat_messages.id)
          GROUP BY uccm.id
        )
        UPDATE user_chat_channel_memberships uccm
        SET last_unread_mention_when_emailed_id = um.last_chat_message_id
        FROM unread_messages um
        WHERE uccm.id = um.membership_id
        AND uccm.user_id = #{user.id}
        RETURNING um.membership_id, um.chat_channel_id, um.first_chat_message_id
      SQL

      @grouped_channels = chat_messages_for(unread_mentions, guardian)

      @grouped_dms =
        user.user_option.allow_private_messages ? chat_messages_for(unread_messages, guardian) : {}

      @count = @grouped_channels.values.sum(&:size) + @grouped_dms.values.sum(&:size)

      return if @count.zero?

      @user_tz = UserOption.user_tzinfo(user.id)
      @preferences_path = "#{Discourse.base_url}/my/preferences/chat"

      build_summary_for(user)

      build_email(
        user.email,
        from_alias: chat_summary_from_alias,
        subject: chat_summary_subject(@grouped_channels, @grouped_dms, @count),
      )
    end

    private

    def chat_messages_for(data, guardian)
      # Note: we probably want to limit the number of messages we fetch
      # since we only display the first 2 per channel in the email
      # I've left this as if for now because we also display the total count
      # and a count of unread messages per channel
      Chat::Message
        .includes(:user, :chat_channel)
        .where(chat_channel_id: data.map { _1[1] })
        .where(
          "chat_messages.id >= (
              SELECT min_unread_id 
              FROM (VALUES #{data.map { "(#{_1[1]}, #{_1[2]})" }.join(",")}) AS t(channel_id, min_unread_id) 
              WHERE t.channel_id = chat_messages.chat_channel_id
            )",
        )
        .order(created_at: :asc)
        .group_by(&:chat_channel)
        .select { |channel, _| guardian.can_join_chat_channel?(channel) }
    end

    def chat_summary_from_alias
      I18n.t("user_notifications.chat_summary.from", site_name: @site_name)
    end

    def subject(type, **args)
      I18n.t("user_notifications.chat_summary.subject.#{type}", { site_name: @site_name, **args })
    end

    def chat_summary_subject(grouped_channels, grouped_dms, count)
      return subject(:private_email, count:) if SiteSetting.private_email

      # consider "direct messages" with more than 2 users as group messages (aka. channels)
      dms, groups = grouped_dms.keys.partition { _1.user_chat_channel_memberships.count == 2 }

      channels = grouped_channels.keys + groups

      if channels.any?
        if dms.any?
          subject(
            :chat_channel_and_dm,
            channel: channels.first.title(@user),
            name: dms.first.title(@user),
          )
        elsif channels.size == 1
          subject(
            :chat_channel_1,
            channel: channels.first.title(@user),
            count: (grouped_channels[channels.first] || grouped_dms[channels.first]).size,
          )
        elsif channels.size == 2
          subject(
            :chat_channel_2,
            channel_1: channels.first.title(@user),
            channel_2: channels.second.title(@user),
          )
        else
          subject(
            :chat_channel_3_or_more,
            channel: channels.first.title(@user),
            count: channels.size - 1,
          )
        end
      elsif dms.size == 1
        subject(:chat_dm_1, name: dms.first.title(@user), count: grouped_dms[dms.first].size)
      elsif dms.size == 2
        subject(:chat_dm_2, name_1: dms.first.title(@user), name_2: dms.second.title(@user))
      elsif dms.size >= 3
        subject(:chat_dm_3_or_more, name: dms.first.title(@user), count: dms.size - 1)
      else
        subject(:private_email, count:)
      end
    end
  end
end
