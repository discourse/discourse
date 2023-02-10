# frozen_string_literal: true

# For various reasons, the sender may receive a warning when writing a mention:
#
# * The target user either cannot chat or cannot see the chat channel, in which case
#   they are defined as `cannot_see`
# * The target user is not a member of the channel, in which case they are defined
#   as `without_membership`
#
# For any users that fall under the `cannot_see` or `without_membership` umbrellas
# we send a MessageBus message to the UI and to inform the sender. The
# creating user can invite any `without_membership` users to the channel. Target
# users who are ignoring or muting the creating user _do not_ fall into this bucket.
class Chat::MessageMentionWarnings
  def dispatch(chat_message)
    direct_mentions = direct_mentions_from(chat_message)
    group_mentions = group_mentions_from(chat_message)

    if (direct_mentions.length + group_mentions.length) > SiteSetting.max_mentions_per_chat_message
      return
    end

    warnings = { without_membership: [], cannot_see: [] }

    append_direct_mention_warnings(warnings, chat_message, direct_mentions)
    append_group_mention_warnings(warnings, chat_message, direct_mentions, group_mentions)
    filter_users_ignoring_or_muting_creator(warnings, chat_message)

    notify_creator_of_inaccessible_mentions(warnings, chat_message)
  end

  private

  def not_participating_base_query(message)
    User
      .distinct
      .real
      .not_suspended
      .joins(:user_option)
      .where(user_options: { chat_enabled: true })
      .where.not(id: message.user_id)
      .includes(:user_chat_channel_memberships)
  end

  def normalized_mentions(raw_mentions)
    raw_mentions.reduce([]) do |memo, mention|
      %w[@here @all].include?(mention.downcase) ? memo : (memo << mention[1..-1].downcase)
    end
  end

  ### Direct mention warning methods

  def direct_mentions_from(message)
    normalized_mentions(Nokogiri::HTML5.fragment(message.cooked).css(".mention").map(&:text))
  end

  def direct_mentioned_users_not_participating(message, mentions)
    not_participating_base_query(message)
      .where.not(id: message.user_id)
      .where(username_lower: mentions)
  end

  def append_direct_mention_warnings(warnings, message, mentions)
    direct_mentioned_users_not_participating(message, mentions).each do |potential_participant|
      guardian = Guardian.new(potential_participant)

      if guardian.can_chat? && guardian.can_join_chat_channel?(message.chat_channel)
        not_a_member =
          potential_participant.user_chat_channel_memberships.none? do |m|
            predicate = m.chat_channel_id == message.chat_channel_id
            predicate = predicate && m.following == true if message.chat_channel.public_channel?
            predicate
          end

        warnings[:without_membership] << potential_participant if not_a_member
      else
        warnings[:cannot_see] << potential_participant
      end
    end
  end

  ### Group mention warning methods

  def group_mentions_from(message)
    normalized_mentions(Nokogiri::HTML5.fragment(message.cooked).css(".mention-group").map(&:text))
  end

  def group_members_not_participating(mentionable_groups, message, direct_mentions)
    not_participating_base_query(message)
      .where.not(id: message.user_id)
      .where.not(username_lower: direct_mentions)
      .joins(:group_users)
      .where(group_users: { group_id: mentionable_groups.map(&:id) })
  end

  def append_group_mention_warnings(warnings, message, direct_mentions, group_mentions)
    visible_groups = Group.where("LOWER(name) IN (?)", group_mentions).visible_groups(message.user)

    return if visible_groups.empty?

    mentionable_groups =
      Group.mentionable(message.user, include_public: false).where(id: visible_groups.map(&:id))

    mentions_disabled = visible_groups - mentionable_groups

    too_many_members, mentionable =
      mentionable_groups.partition do |group|
        group.user_count > SiteSetting.max_users_notified_per_group_mention
      end

    warnings[:group_mentions_disabled] = mentions_disabled
    warnings[:too_many_members] = too_many_members

    group_members_not_participating(
      mentionable,
      message,
      direct_mentions,
    ).each do |potential_participant|
      guardian = Guardian.new(potential_participant)

      if guardian.can_chat? && guardian.can_join_chat_channel?(message.chat_channel)
        not_a_member =
          potential_participant.user_chat_channel_memberships.none? do |m|
            predicate = m.chat_channel_id == message.chat_channel_id
            predicate = predicate && m.following == true if message.chat_channel.public_channel?
            predicate
          end

        warnings[:without_membership] << potential_participant if not_a_member
      else
        warnings[:cannot_see] << potential_participant
      end
    end
  end

  ### Apply ignore/mute filters

  def filter_users_ignoring_or_muting_creator(warnings, message)
    screen_targets = warnings[:without_membership].map(&:id)

    return if screen_targets.blank?

    screener = UserCommScreener.new(acting_user: message.user, target_user_ids: screen_targets)

    warnings[:without_membership].reject! { |user| screener.ignoring_or_muting_actor?(user.id) }
  end

  ### Notify client

  def notify_creator_of_inaccessible_mentions(warnings, message)
    return if warnings.values.all?(&:blank?)

    warnings_payload = [
      inaccessible_mention_payload(warnings, :cannot_see) { |user| user.username },
      inaccessible_mention_payload(warnings, :without_membership, include_ids: true) do |user|
        user.username
      end,
      inaccessible_mention_payload(warnings, :too_many_members) { |group| group.name },
      inaccessible_mention_payload(warnings, :group_mentions_disabled) { |group| group.name },
    ].compact

    ChatPublisher.publish_inaccessible_mentions(message.user_id, message, warnings_payload)
  end

  def inaccessible_mention_payload(warnings, type, include_ids: false)
    return if warnings[type].blank?
    payload = { type: type, mentions: [] }

    payload[:mention_target_ids] = [] if include_ids

    warnings[type].reduce(payload) do |memo, target|
      memo[:mentions] << yield(target)
      memo[:mention_target_ids] << target.id if include_ids
      memo
    end
  end
end
