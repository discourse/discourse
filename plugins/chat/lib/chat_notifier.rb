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
  class << self
    def user_has_seen_message?(membership, chat_message_id)
      (membership.last_read_message_id || 0) >= chat_message_id
    end

    def push_notification_tag(type, chat_channel_id)
      "#{Discourse.current_hostname}-chat-#{type}-#{chat_channel_id}"
    end

    def notify_edit(chat_message:, timestamp:)
      Jobs.enqueue(
        :send_message_notifications,
        chat_message_id: chat_message.id,
        timestamp: timestamp.iso8601(6),
        reason: :edit,
      )
    end

    def notify_new(chat_message:, timestamp:)
      Jobs.enqueue(
        :send_message_notifications,
        chat_message_id: chat_message.id,
        timestamp: timestamp.iso8601(6),
        reason: :new,
      )
    end
  end

  def initialize(chat_message, timestamp)
    @chat_message = chat_message
    @timestamp = timestamp
    @chat_channel = @chat_message.chat_channel
    @user = @chat_message.user
    @mentions = Chat::ChatMessageMentions.new(chat_message)
  end

  ### Public API

  def notify_new
    to_notify = list_users_to_notify
    mentioned_user_ids = to_notify.extract!(:all_mentioned_user_ids)[:all_mentioned_user_ids]

    mentioned_user_ids.each do |member_id|
      ChatPublisher.publish_new_mention(member_id, @chat_channel.id, @chat_message.id)
    end

    notify_creator_of_inaccessible_mentions(to_notify)

    notify_mentioned_users(to_notify)
    notify_watching_users(except: mentioned_user_ids << @user.id)

    to_notify
  end

  def notify_edit
    existing_notifications =
      ChatMention.includes(:user, :notification).where(chat_message: @chat_message)
    already_notified_user_ids = existing_notifications.map(&:user_id)

    to_notify = list_users_to_notify
    mentioned_user_ids = to_notify.extract!(:all_mentioned_user_ids)[:all_mentioned_user_ids]

    needs_deletion = already_notified_user_ids - mentioned_user_ids
    needs_deletion.each do |user_id|
      chat_mention = existing_notifications.detect { |n| n.user_id == user_id }
      chat_mention.notification.destroy!
      chat_mention.destroy!
    end

    needs_notification_ids = mentioned_user_ids - already_notified_user_ids
    return if needs_notification_ids.blank?

    notify_creator_of_inaccessible_mentions(to_notify)

    notify_mentioned_users(to_notify, already_notified_user_ids: already_notified_user_ids)

    to_notify
  end

  private

  def list_users_to_notify
    mentions_count =
      @mentions.parsed_direct_mentions.length + @mentions.parsed_group_mentions.length
    mentions_count += 1 if @mentions.has_global_mention
    mentions_count += 1 if @mentions.has_here_mention

    skip_notifications = mentions_count > SiteSetting.max_mentions_per_chat_message

    {}.tap do |to_notify|
      # The order of these methods is the precedence
      # between different mention types.

      already_covered_ids = []

      expand_direct_mentions(to_notify, already_covered_ids, skip_notifications)
      expand_group_mentions(to_notify, already_covered_ids, skip_notifications)
      expand_here_mention(to_notify, already_covered_ids, skip_notifications)
      expand_global_mention(to_notify, already_covered_ids, skip_notifications)

      filter_users_ignoring_or_muting_creator(to_notify, already_covered_ids)

      to_notify[:all_mentioned_user_ids] = already_covered_ids
    end
  end

  def expand_global_mention(to_notify, already_covered_ids, skip)
    has_all_mention = @mentions.has_global_mention

    if has_all_mention && @chat_channel.allow_channel_wide_mentions && !skip
      to_notify[:global_mentions] = @mentions
        .global_mentions
        .where(user_options: { ignore_channel_wide_mention: [false, nil] })
        .where.not(id: already_covered_ids)
        .pluck(:id)

      already_covered_ids.concat(to_notify[:global_mentions])
    else
      to_notify[:global_mentions] = []
    end
  end

  def expand_here_mention(to_notify, already_covered_ids, skip)
    has_here_mention = @mentions.has_here_mention

    if has_here_mention && @chat_channel.allow_channel_wide_mentions && !skip
      to_notify[:here_mentions] = @mentions
        .here_mentions
        .where(user_options: { ignore_channel_wide_mention: [false, nil] })
        .where.not(id: already_covered_ids)
        .pluck(:id)

      already_covered_ids.concat(to_notify[:here_mentions])
    else
      to_notify[:here_mentions] = []
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

  def expand_direct_mentions(to_notify, already_covered_ids, skip)
    if skip
      direct_mentions = []
    else
      direct_mentions = @mentions.direct_mentions.where.not(id: already_covered_ids)
    end

    grouped = group_users_to_notify(direct_mentions)

    to_notify[:direct_mentions] = grouped[:already_participating].map(&:id)
    to_notify[:welcome_to_join] = grouped[:welcome_to_join]
    to_notify[:unreachable] = grouped[:unreachable]
    already_covered_ids.concat(to_notify[:direct_mentions])
  end

  def expand_group_mentions(to_notify, already_covered_ids, skip)
    return [] if skip || @mentions.visible_groups.empty?

    reached_by_group =
      @mentions
        .group_mentions
        .where("user_count <= ?", SiteSetting.max_users_notified_per_group_mention)
        .where.not(id: already_covered_ids)

    too_many_members, mentionable =
      @mentions.mentionable_groups.partition do |group|
        group.user_count > SiteSetting.max_users_notified_per_group_mention
      end

    mentions_disabled = @mentions.visible_groups - @mentions.mentionable_groups
    to_notify[:group_mentions_disabled] = mentions_disabled
    to_notify[:too_many_members] = too_many_members
    mentionable.each { |g| to_notify[g.name.downcase] = [] }

    grouped = group_users_to_notify(reached_by_group)
    grouped[:already_participating].each do |user|
      # When a user is a member of multiple mentioned groups,
      # the most far to the left should take precedence.
      ordered_group_names =
        @mentions.parsed_group_mentions & mentionable.map { |mg| mg.name.downcase }
      user_group_names = user.groups.map { |ug| ug.name.downcase }
      group_name = ordered_group_names.detect { |gn| user_group_names.include?(gn) }

      to_notify[group_name] << user.id
      already_covered_ids << user.id
    end

    to_notify[:welcome_to_join] = to_notify[:welcome_to_join].concat(grouped[:welcome_to_join])
    to_notify[:unreachable] = to_notify[:unreachable].concat(grouped[:unreachable])
  end

  def notify_creator_of_inaccessible_mentions(to_notify)
    inaccessible =
      to_notify.extract!(
        :unreachable,
        :welcome_to_join,
        :too_many_members,
        :group_mentions_disabled,
      )
    return if inaccessible.values.all?(&:blank?)

    ChatPublisher.publish_inaccessible_mentions(
      @user.id,
      @chat_message,
      inaccessible[:unreachable].to_a,
      inaccessible[:welcome_to_join].to_a,
      inaccessible[:too_many_members].to_a,
      inaccessible[:group_mentions_disabled].to_a,
    )
  end

  # Filters out users from global, here, group, and direct mentions that are
  # ignoring or muting the creator of the message, so they will not receive
  # a notification via the ChatNotifyMentioned job and are not prompted for
  # invitation by the creator.
  def filter_users_ignoring_or_muting_creator(to_notify, already_covered_ids)
    screen_targets = already_covered_ids.concat(to_notify[:welcome_to_join].map(&:id))

    return if screen_targets.blank?

    screener = UserCommScreener.new(acting_user: @user, target_user_ids: screen_targets)
    to_notify
      .except(:unreachable, :welcome_to_join)
      .each do |key, user_ids|
        to_notify[key] = user_ids.reject { |user_id| screener.ignoring_or_muting_actor?(user_id) }
      end

    # :welcome_to_join contains users because it's serialized by MB.
    to_notify[:welcome_to_join] = to_notify[:welcome_to_join].reject do |user|
      screener.ignoring_or_muting_actor?(user.id)
    end

    already_covered_ids.reject! do |already_covered|
      screener.ignoring_or_muting_actor?(already_covered)
    end
  end

  def notify_mentioned_users(to_notify, already_notified_user_ids: [])
    Jobs.enqueue(
      :chat_notify_mentioned,
      {
        chat_message_id: @chat_message.id,
        to_notify_ids_map: to_notify.as_json,
        already_notified_user_ids: already_notified_user_ids,
        timestamp: @timestamp,
      },
    )
  end

  def notify_watching_users(except: [])
    Jobs.enqueue(
      :chat_notify_watching,
      { chat_message_id: @chat_message.id, except_user_ids: except, timestamp: @timestamp },
    )
  end
end
