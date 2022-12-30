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
    if (inaccessible_mentions = expand_mentions_and_notify)
      notify_creator_of_inaccessible_mentions(inaccessible_mentions)
    end

    global_mentions = []
    global_mentions << "all" if typed_global_mention?
    global_mentions << "here" if typed_here_mention?

    notify_watching_users(
      mentioned_channel_member_ids,
      global_mentions,
      mentionable_groups.map(&:id)
    )
  end

  def notify_edit
    purge_outdated_mentions

    if (inaccessible_mentions = expand_mentions_and_notify)
      notify_creator_of_inaccessible_mentions(inaccessible_mentions)
    end
  end

  private

  def purge_outdated_mentions
    ChatMention
      .joins(user: :groups)
      .where(chat_message: @chat_message)
      .where.not(user_id: mentioned_channel_member_ids)
      .where.not(groups: { id: mentionable_groups.map(&:id) })
      .destroy_all
  end

  def expand_mentions_and_notify
    direct_mentions_count = direct_mentions_from_cooked.length
    group_mentions_count = group_name_mentions.length

    skip_notifications =
      (direct_mentions_count + group_mentions_count) >
        SiteSetting.max_mentions_per_chat_message

    inaccessible_mentions = {
      welcome_to_join: [],
      unreachable: [],
      group_mentions_disabled: [],
      too_many_members: []
    }

    return inaccessible_mentions if skip_notifications

    send_direct_mentions(inaccessible_mentions)
    send_group_mentions(inaccessible_mentions)
    filter_invites_ignoring_or_muting_creator(inaccessible_mentions)

    if @chat_channel.allow_channel_wide_mentions?
      send_here_mentions if typed_here_mention?
      send_global_mentions if typed_global_mention?
    end

    inaccessible_mentions
  end

  def send_direct_mentions(inaccessible_mentions)
    direct_mentions = chat_users.where(username_lower: usernames_mentioned)

    grouped = group_users_to_notify(direct_mentions)
    inaccessible_mentions[:welcome_to_join] = grouped[:welcome_to_join]
    inaccessible_mentions[:unreachable] = grouped[:unreachable]

    notify_mentioned_users(DIRECT_MENTIONS, grouped[:already_participating].map(&:id))
  end

  def send_group_mentions(inaccessible_mentions)
    return if visible_groups.empty?

    mentions_disabled = visible_groups - mentionable_groups

    too_many_members, mentionable = mentionable_groups.partition do |group|
      group.user_count > SiteSetting.max_users_notified_per_group_mention
    end

    inaccessible_mentions[:group_mentions_disabled] = mentions_disabled
    inaccessible_mentions[:too_many_members] = too_many_members

    reached_by_group = chat_users
      .where.not(id: mentioned_channel_member_ids)
      .joins(:groups)
      .where(groups: { id: mentionable.map(&:id) })
      .group('users.id')
      .select("users.*", "ARRAY_AGG(LOWER(groups.name)) AS mentioned_group_names")

    grouped = group_users_to_notify(reached_by_group)
    ordered_group_names = group_name_mentions & mentionable.map { |mg| mg.name.downcase }

    classified = grouped[:already_participating].reduce({}) do |memo, member|
      first_mentioned_group = ordered_group_names.detect { |gn| member.mentioned_group_names.include?(gn) }

      memo[first_mentioned_group] = memo[first_mentioned_group].to_a << member.id

      memo
    end

    classified.each do |group_name, member_ids|
      notify_mentioned_users(group_name, member_ids)
    end

    inaccessible_mentions[:welcome_to_join] = inaccessible_mentions[:welcome_to_join].concat(grouped[:welcome_to_join])
    inaccessible_mentions[:unreachable] = inaccessible_mentions[:unreachable].concat(grouped[:unreachable])
  end

  def send_here_mentions
    here_user_ids = channel_wide_mentions(mentionable_groups.map(&:id))
      .where("last_seen_at > ?", 5.minutes.ago)
      .pluck(:id)

    notify_mentioned_users(HERE_MENTIONS, here_user_ids)
  end

  def send_global_mentions
    global_mentions = channel_wide_mentions(mentionable_groups.map(&:id))

    if typed_here_mention?
      global_mentions = global_mentions
        .where("last_seen_at < ?", 5.minutes.ago)
    end

    notify_mentioned_users(GLOBAL_MENTIONS, global_mentions.pluck(:id))
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
      already_participating: participants.to_a,
      welcome_to_join: welcome_to_join.to_a,
      unreachable: unreachable.to_a,
    }
  end

  def notify_creator_of_inaccessible_mentions(inaccessible_mentions)
    return if inaccessible_mentions.values.all?(&:blank?)

    ChatPublisher.publish_inaccessible_mentions(
      @user.id,
      @chat_message,
      inaccessible_mentions[:unreachable],
      inaccessible_mentions[:welcome_to_join],
      inaccessible_mentions[:too_many_members],
      inaccessible_mentions[:group_mentions_disabled]
    )
  end

  # Filters out users from global, here, group, and direct mentions that are
  # ignoring or muting the creator of the message, so they will not receive
  # a notification via the ChatNotifyMentioned job and are not prompted for
  # invitation by the creator.
  def filter_invites_ignoring_or_muting_creator(inaccessible_mentions)
    screen_targets = inaccessible_mentions[:welcome_to_join].map(&:id)

    return if screen_targets.blank?

    screener = UserCommScreener.new(acting_user: @user, target_user_ids: screen_targets)

    # :welcome_to_join contains users because it's serialized by MB.
    inaccessible_mentions[:welcome_to_join] = inaccessible_mentions[:welcome_to_join].reject do |user|
      screener.ignoring_or_muting_actor?(user.id)
    end
  end

  # Query helpers

  def mentioned_channel_member_ids
    @mentioned_channel_member_ids ||= begin
      where_params = { chat_channel_id: @chat_channel.id }
      where_params[:following] = true if @chat_channel.public_channel?

      chat_users.where(uccm: where_params).where(username_lower: usernames_mentioned).pluck(:id)
    end
  end

  def visible_groups
    @visible_groups ||=
      Group
        .where("LOWER(name) IN (?)", group_name_mentions)
        .visible_groups(@user)
  end

  def mentionable_groups
    @mentioned_groups ||= Group
      .mentionable(@user, include_public: false)
      .where(id: visible_groups.map(&:id))
  end

  def channel_wide_mentions(mentioned_group_ids)
    query = members_accepting_channel_wide_notifications
      .where.not(id: mentioned_channel_member_ids)

    return query if mentioned_group_ids.blank?

    query
      .distinct
      .joins(:group_users)
      .group('users.id')
      .having('bool_and(group_users.group_id NOT IN (?))', mentioned_group_ids)
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

  # Jobs to create notifications

  def notify_mentioned_users(mention_type, user_ids)
    return if user_ids.blank?

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

  # Helper methods for capturing mentions

  def group_name_mentions
    @group_mentions_from_cooked ||=
      normalized_mentions(
        Nokogiri::HTML5.fragment(@chat_message.cooked).css(".mention-group").map(&:text),
      )
  end

  def direct_mentions_from_cooked
    @direct_mentions_from_cooked ||=
      Nokogiri::HTML5.fragment(@chat_message.cooked)
        .css(".mention").map { |node| node.text.downcase }
  end

  def usernames_mentioned
    @usernames_mentioned ||= normalized_mentions(direct_mentions_from_cooked)
  end

  def normalized_mentions(mentions)
    mentions.reduce([]) do |memo, mention|
      %w[@here @all].include?(mention) ? memo : (memo << mention[1..-1])
    end
  end

  def typed_global_mention?
    direct_mentions_from_cooked.include?("@all")
  end

  def typed_here_mention?
    direct_mentions_from_cooked.include?("@here")
  end
end
