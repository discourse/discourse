# frozen_string_literal: true

##
# When we are attempting to notify users based on a message we have to take
# into account the following:
#
# * Individual user mentions like @alfred
# * Group mentions that include N users such as @support
# * Global @here and @all mentions
# * Users watching the channel via UserChatChannelMembership
#
# For various reasons a mention may not notify a user:
#
# * The target user of the mention is ignoring or muting the user who created the message
# * The target user either cannot chat or cannot see the chat channel, in which case
#   they are defined as `unreachable`
# * The target user is not a member of the channel, in which case they are defined
#   as `welcome_to_join`
# * In the case of global @here and @all mentions users with the preference
#   `ignore_channel_wide_mention` set to true will not be notified
#
# For any users that fall under the `unreachable` or `welcome_to_join` umbrellas
# we send a MessageBus message to the UI and to inform the creating user. The
# creating user can invite any `welcome_to_join` users to the channel. Target
# users who are ignoring or muting the creating user _do not_ fall into this bucket.
#
# The ignore/mute filtering is also applied via the ChatNotifyWatching job,
# which prevents desktop / push notifications being sent.
class Chat::ChatNotifier
  DIRECT_MENTIONS = :direct_mentions
  HERE_MENTIONS = :here_mentions
  GLOBAL_MENTIONS = :global_mentions
  STATIC_MENTION_TYPES = [DIRECT_MENTIONS, HERE_MENTIONS, GLOBAL_MENTIONS]

  class << self
    def push_notification_tag(type, chat_channel_id)
      "#{Discourse.current_hostname}-chat-#{type}-#{chat_channel_id}"
    end

    def notify_edit(chat_message:, timestamp:)
      Jobs.enqueue(
        :send_message_notifications,
        chat_message_id: chat_message.id,
        timestamp: timestamp.iso8601(6),
        reason: "edit"
      )
    end

    def notify_new(chat_message:, timestamp:)
      Jobs.enqueue(
        :send_message_notifications,
        chat_message_id: chat_message.id,
        timestamp: timestamp.iso8601(6),
        reason: "new"
      )
    end
  end

  def initialize(chat_message, timestamp)
    @chat_message = chat_message
    @timestamp = timestamp
    @chat_channel = @chat_message.chat_channel
    @user = @chat_message.user
  end

  ### Public API

  def notify_new
    to_notify = list_users_to_notify

    notify_creator_of_inaccessible_mentions(to_notify)

    to_notify.each do |mention_type, user_ids|
      notify_mentioned_users(mention_type, user_ids)
    end

    global_mentions = []
    global_mentions << "all" if typed_global_mention?
    global_mentions << "here" if typed_here_mention?

    notify_watching_users(
      to_notify[DIRECT_MENTIONS],
      global_mentions,
      to_notify[:mentioned_group_ids]
    )

    to_notify
  end

  def notify_edit
    to_notify = list_users_to_notify

    purge_outdated_mentions(to_notify)
    notify_creator_of_inaccessible_mentions(to_notify)

    to_notify.each do |mention_type, user_ids|
      notify_mentioned_users(mention_type, user_ids)
    end

    to_notify
  end

  private

  def typed_global_mention?
    direct_mentions_from_cooked.include?("@all")
  end

  def typed_here_mention?
    direct_mentions_from_cooked.include?("@here")
  end

  def purge_outdated_mentions(to_notify)
    ChatMention
      .joins(user: :groups)
      .where(chat_message: @chat_message)
      .where.not(user_id: to_notify[:direct_mentions])
      .where.not(groups: { id: to_notify[:mentioned_group_ids] })
      .destroy_all
  end

  def list_users_to_notify
    direct_mentions_count = direct_mentions_from_cooked.length
    group_mentions_count = group_name_mentions.length

    skip_notifications =
      (direct_mentions_count + group_mentions_count) >
        SiteSetting.max_mentions_per_chat_message

    {}.tap do |to_notify|
      # The order of these methods is the precedence
      # between different mention types.

      expand_direct_mentions(to_notify, skip_notifications)
      expand_group_mentions(to_notify, skip_notifications)
      expand_here_mention(to_notify, skip_notifications)
      expand_global_mention(to_notify, skip_notifications)

      filter_invites_ignoring_or_muting_creator(to_notify)
    end
  end

  def chat_users
    User
      .includes(:user_chat_channel_memberships, :group_users)
      .distinct
      .joins("LEFT OUTER JOIN user_chat_channel_memberships uccm ON uccm.user_id = users.id")
      .joins(:user_option)
      .real
      .not_suspended
      .where(user_options: { chat_enabled: true })
      .where.not(username_lower: @user.username.downcase)
  end

  def channel_members
    chat_users.where(
      uccm: {
        following: true,
        chat_channel_id: @chat_channel.id,
      },
    )
  end

  def members_accepting_channel_wide_notifications
    channel_members.where(user_options: { ignore_channel_wide_mention: [false, nil] })
  end

  def direct_mentions_from_cooked
    @direct_mentions_from_cooked ||=
      Nokogiri::HTML5.fragment(@chat_message.cooked).css(".mention").map(&:text)
  end

  def normalized_mentions(mentions)
    mentions.reduce([]) do |memo, mention|
      %w[@here @all].include?(mention.downcase) ? memo : (memo << mention[1..-1].downcase)
    end
  end

  def channel_wide_mentions(mentioned_group_ids)
    query = members_accepting_channel_wide_notifications
      .where.not(username_lower: normalized_mentions(direct_mentions_from_cooked))

    return query if mentioned_group_ids.blank?

    query
      .distinct
      .joins(:group_users)
      .group('users.id')
      .having('bool_and(group_users.group_id NOT IN (?))', mentioned_group_ids)
  end

  def expand_global_mention(to_notify, skip)
    if typed_global_mention? && @chat_channel.allow_channel_wide_mentions && !skip
      global_mentions = channel_wide_mentions(to_notify[:mentioned_group_ids])

      if typed_here_mention?
        global_mentions = global_mentions
          .where("last_seen_at < ?", 5.minutes.ago)
      end

      to_notify[GLOBAL_MENTIONS] = global_mentions.pluck(:id)
    else
      to_notify[GLOBAL_MENTIONS] = []
    end
  end

  def expand_here_mention(to_notify, skip)
    if typed_here_mention? && @chat_channel.allow_channel_wide_mentions && !skip
      to_notify[HERE_MENTIONS] = channel_wide_mentions(to_notify[:mentioned_group_ids])
        .where("last_seen_at > ?", 5.minutes.ago)
        .pluck(:id)
    else
      to_notify[HERE_MENTIONS] = []
    end
  end

  def group_users_to_notify(users)
    potential_participants, unreachable =
      users.partition do |user|
        guardian = Guardian.new(user)
        guardian.can_chat? && guardian.can_join_chat_channel?(@chat_channel)
      end

    participants, welcome_to_join =
      potential_participants.partition do |participant|
        participant.user_chat_channel_memberships.any? do |m|
          predicate = m.chat_channel_id == @chat_channel.id
          predicate = predicate && m.following == true if @chat_channel.public_channel?
          predicate
        end
      end

    {
      already_participating: participants || [],
      welcome_to_join: welcome_to_join || [],
      unreachable: unreachable || [],
    }
  end

  def expand_direct_mentions(to_notify, skip)
    if skip
      direct_mentions = []
    else
      direct_mentions =
        chat_users
          .where(username_lower: normalized_mentions(direct_mentions_from_cooked))
    end

    grouped = group_users_to_notify(direct_mentions)

    to_notify[DIRECT_MENTIONS] = grouped[:already_participating].map(&:id)
    to_notify[:welcome_to_join] = grouped[:welcome_to_join]
    to_notify[:unreachable] = grouped[:unreachable]
  end

  def group_name_mentions
    @group_mentions_from_cooked ||=
      normalized_mentions(
        Nokogiri::HTML5.fragment(@chat_message.cooked).css(".mention-group").map(&:text),
      )
  end

  def visible_groups
    @visible_groups ||=
        Group
          .where("LOWER(name) IN (?)", group_name_mentions)
          .visible_groups(@user)
  end

  def expand_group_mentions(to_notify, skip)
    return [] if skip || visible_groups.empty?

    mentionable_groups = Group
      .mentionable(@user, include_public: false)
      .where(id: visible_groups.map(&:id))

    mentions_disabled = visible_groups - mentionable_groups

    too_many_members, mentionable = mentionable_groups.partition do |group|
      group.user_count > SiteSetting.max_users_notified_per_group_mention
    end

    to_notify[:mentioned_group_ids] = mentionable.map(&:id)
    to_notify[:group_mentions_disabled] = mentions_disabled
    to_notify[:too_many_members] = too_many_members

    mentionable.each { |g| to_notify[g.name.downcase] = [] }

    reached_by_group =
      chat_users
        .where.not(username_lower: normalized_mentions(direct_mentions_from_cooked))
        .joins(:group_users)
        .group('users.id')
        .having('bool_or(group_users.group_id IN (?))', to_notify[:mentioned_group_ids])

    grouped = group_users_to_notify(reached_by_group)

    grouped[:already_participating].each do |user|
      # When a user is a member of multiple mentioned groups,
      # the most far to the left should take precedence.
      ordered_group_names = group_name_mentions & mentionable.map { |mg| mg.name.downcase }
      user_group_names = user.groups.map { |ug| ug.name.downcase }
      group_name = ordered_group_names.detect { |gn| user_group_names.include?(gn) }

      to_notify[group_name] << user.id
    end

    to_notify[:welcome_to_join] = to_notify[:welcome_to_join].concat(grouped[:welcome_to_join])
    to_notify[:unreachable] = to_notify[:unreachable].concat(grouped[:unreachable])
  end

  def notify_creator_of_inaccessible_mentions(to_notify)
    inaccessible = to_notify.extract!(:unreachable, :welcome_to_join, :too_many_members, :group_mentions_disabled)
    return if inaccessible.values.all?(&:blank?)

    ChatPublisher.publish_inaccessible_mentions(
      @user.id,
      @chat_message,
      inaccessible[:unreachable].to_a,
      inaccessible[:welcome_to_join].to_a,
      inaccessible[:too_many_members].to_a,
      inaccessible[:group_mentions_disabled].to_a
    )
  end

  # Filters out users from global, here, group, and direct mentions that are
  # ignoring or muting the creator of the message, so they will not receive
  # a notification via the ChatNotifyMentioned job and are not prompted for
  # invitation by the creator.
  def filter_invites_ignoring_or_muting_creator(to_notify)
    screen_targets = to_notify[:welcome_to_join].map(&:id)

    return if screen_targets.blank?

    screener = UserCommScreener.new(acting_user: @user, target_user_ids: screen_targets)

    # :welcome_to_join contains users because it's serialized by MB.
    to_notify[:welcome_to_join] = to_notify[:welcome_to_join].reject do |user|
      screener.ignoring_or_muting_actor?(user.id)
    end
  end

  def notify_mentioned_users(mention_type, user_ids)
    Jobs.enqueue(
      :chat_notify_mentioned,
      {
        chat_message_id: @chat_message.id,
        user_ids: user_ids,
        mention_type: mention_type,
        timestamp: @timestamp.iso8601(6),
      },
    )
  end

  def notify_watching_users(direct_mentioned_user_ids, global_mentions, mentioned_group_ids)
    Jobs.enqueue(
      :chat_notify_watching,
      {
        chat_message_id: @chat_message.id,
        timestamp: @timestamp.iso8601(6),
        direct_mentioned_user_ids: direct_mentioned_user_ids,
        global_mentions: global_mentions,
        mentioned_group_ids: mentioned_group_ids
      },
    )
  end
end
