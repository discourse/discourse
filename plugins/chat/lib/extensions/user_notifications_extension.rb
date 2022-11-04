# frozen_string_literal: true

module Chat::UserNotificationsExtension
  def chat_summary(user, opts)
    guardian = Guardian.new(user)
    return unless guardian.can_chat?(user)

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
      @grouped_messages.select { |channel, _| guardian.can_see_chat_channel?(channel) }
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
    channels = grouped_messages.keys
    grouped_channels = channels.partition { |c| !c.direct_message_channel? }
    non_dm_channels = grouped_channels.first
    dm_users = grouped_channels.last.flat_map { |c| grouped_messages[c].map(&:user) }.uniq

    total_count_for_subject = non_dm_channels.size + dm_users.size
    first_message_from = non_dm_channels.pop
    if first_message_from
      first_message_title = first_message_from.title(user)
      subject_key = "chat_channel"
    else
      subject_key = "direct_message"
      first_message_from = dm_users.pop
      first_message_title = first_message_from.username
    end

    subject_opts = {
      email_prefix: @email_prefix,
      count: total_count_for_subject,
      message_title: first_message_title,
      others:
        other_channels_text(
          user,
          total_count_for_subject,
          first_message_from,
          non_dm_channels,
          dm_users,
        ),
    }

    I18n.t(with_subject_prefix(subject_key), **subject_opts)
  end

  def with_subject_prefix(key)
    "user_notifications.chat_summary.subject.#{key}"
  end

  def other_channels_text(
    user,
    total_count,
    first_message_from,
    other_non_dm_channels,
    other_dm_users
  )
    return if total_count <= 1
    return I18n.t(with_subject_prefix("others"), count: total_count - 1) if total_count > 2

    if other_non_dm_channels.empty?
      second_message_from = other_dm_users.first
      second_message_title = second_message_from.username
    else
      second_message_from = other_non_dm_channels.first
      second_message_title = second_message_from.title(user)
    end

    return second_message_title if first_message_from.class == second_message_from.class

    I18n.t(with_subject_prefix("other_direct_message"), message_title: second_message_title)
  end
end
