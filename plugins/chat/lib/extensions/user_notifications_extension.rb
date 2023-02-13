# frozen_string_literal: true

module Chat::UserNotificationsExtension
  def chat_summary(user, opts)
    guardian = Guardian.new(user)
    return unless guardian.can_chat?

    @messages =
      ChatMessage
        .joins(:user, :chat_channel)
        .where.not(user: user)
        .where("chat_messages.created_at > ?", 1.week.ago)
        .joins("LEFT OUTER JOIN chat_mentions cm ON cm.chat_message_id = chat_messages.id")
        .joins(
          "INNER JOIN user_chat_channel_memberships uccm ON uccm.chat_channel_id = chat_channels.id",
        )
        .where(<<~SQL, user_id: user.id)
          uccm.user_id = :user_id AND
          (uccm.last_read_message_id IS NULL OR chat_messages.id > uccm.last_read_message_id) AND
          (uccm.last_unread_mention_when_emailed_id IS NULL OR chat_messages.id > uccm.last_unread_mention_when_emailed_id) AND
          (
            (cm.user_id = :user_id AND uccm.following IS true AND chat_channels.chatable_type = 'Category') OR
            (chat_channels.chatable_type = 'DirectMessage')
          )
        SQL
        .to_a

    return if @messages.empty?
    @grouped_messages = @messages.group_by { |message| message.chat_channel }
    @grouped_messages =
      @grouped_messages.select { |channel, _| guardian.can_join_chat_channel?(channel) }
    return if @grouped_messages.empty?

    @grouped_messages.each do |chat_channel, messages|
      @grouped_messages[chat_channel] = messages.sort_by(&:created_at)
    end
    @user = user
    @user_tz = UserOption.user_tzinfo(user.id)
    @display_usernames = SiteSetting.prioritize_username_in_ux || !SiteSetting.enable_names

    build_summary_for(user)
    @preferences_path = "#{Discourse.base_url}/my/preferences/chat"

    # TODO(roman): Remove after the 2.9 release
    add_unsubscribe_link = UnsubscribeKey.respond_to?(:get_unsubscribe_strategy_for)

    if add_unsubscribe_link
      unsubscribe_key = UnsubscribeKey.create_key_for(@user, "chat_summary")
      @unsubscribe_link = "#{Discourse.base_url}/email/unsubscribe/#{unsubscribe_key}"
      opts[:unsubscribe_url] = @unsubscribe_link
    end

    opts = {
      from_alias: I18n.t("user_notifications.chat_summary.from", site_name: Email.site_title),
      subject: summary_subject(user, @grouped_messages),
      add_unsubscribe_link: add_unsubscribe_link,
    }

    build_email(user.email, opts)
  end

  def summary_subject(user, grouped_messages)
    all_channels = grouped_messages.keys
    grouped_channels = all_channels.partition { |c| !c.direct_message_channel? }
    channels = grouped_channels.first

    dm_messages = grouped_channels.last.flat_map { |c| grouped_messages[c] }
    dm_users = dm_messages.sort_by(&:created_at).uniq { |m| m.user_id }.map(&:user)

    # Prioritize messages from regular channels over direct messages
    if channels.any?
      channel_notification_text(
        channels.sort_by { |channel| [channel.last_message_sent_at, channel.created_at] },
        dm_users,
      )
    else
      direct_message_notification_text(dm_users)
    end
  end

  private

  def channel_notification_text(channels, dm_users)
    total_count = channels.size + dm_users.size

    if total_count > 2
      I18n.t(
        "user_notifications.chat_summary.subject.chat_channel_more",
        email_prefix: @email_prefix,
        channel: channels.first.title,
        count: total_count - 1,
      )
    elsif channels.size == 1 && dm_users.size == 0
      I18n.t(
        "user_notifications.chat_summary.subject.chat_channel_1",
        email_prefix: @email_prefix,
        channel: channels.first.title,
      )
    elsif channels.size == 1 && dm_users.size == 1
      I18n.t(
        "user_notifications.chat_summary.subject.chat_channel_and_direct_message",
        email_prefix: @email_prefix,
        channel: channels.first.title,
        username: dm_users.first.username,
      )
    elsif channels.size == 2
      I18n.t(
        "user_notifications.chat_summary.subject.chat_channel_2",
        email_prefix: @email_prefix,
        channel1: channels.first.title,
        channel2: channels.second.title,
      )
    end
  end

  def direct_message_notification_text(dm_users)
    case dm_users.size
    when 1
      I18n.t(
        "user_notifications.chat_summary.subject.direct_message_from_1",
        email_prefix: @email_prefix,
        username: dm_users.first.username,
      )
    when 2
      I18n.t(
        "user_notifications.chat_summary.subject.direct_message_from_2",
        email_prefix: @email_prefix,
        username1: dm_users.first.username,
        username2: dm_users.second.username,
      )
    else
      I18n.t(
        "user_notifications.chat_summary.subject.direct_message_from_more",
        email_prefix: @email_prefix,
        username: dm_users.first.username,
        count: dm_users.size - 1,
      )
    end
  end
end
