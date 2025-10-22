# frozen_string_literal: true

##
# When we are attempting to notify users based on a message we have to take
# into account the following:
#
# * Individual user mentions like @alfred
# * Group mentions that include N users such as @support
# * Global @here and @all mentions
# * Users watching the channel via Chat::UserChatChannelMembership
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
# The ignore/mute filtering is also applied via the Jobs::Chat::NotifyWatching job,
# which prevents desktop / push notifications being sent.
module Chat
  class Notifier
    class << self
      def user_has_seen_message?(membership, chat_message_id)
        (membership.last_read_message_id || 0) >= chat_message_id
      end

      def push_notification_tag(type, chat_channel_id)
        "#{Discourse.current_hostname}-chat-#{type}-#{chat_channel_id}"
      end

      def notify_edit(chat_message:, timestamp:)
        Jobs.enqueue(
          Jobs::Chat::SendMessageNotifications,
          chat_message_id: chat_message.id,
          timestamp: timestamp.iso8601(6),
          reason: "edit",
        )
      end

      def notify_new(chat_message:, timestamp:)
        Jobs.enqueue(
          Jobs::Chat::SendMessageNotifications,
          chat_message_id: chat_message.id,
          timestamp: timestamp.iso8601(6),
          reason: "new",
        )
      end
    end

    def initialize(chat_message, timestamp)
      @chat_message = chat_message
      @parsed_mentions = @chat_message.parsed_mentions
      @timestamp = timestamp
      @chat_channel = @chat_message.chat_channel
      @user = @chat_message.user
    end

    ### Public API

    def notify_new
      to_notify, inaccessible, all_mentioned_user_ids = list_users_to_notify

      all_mentioned_user_ids.each do |member_id|
        Chat::Publisher.publish_new_mention(member_id, @chat_channel.id, @chat_message.id)
      end

      notify_creator_of_inaccessible_mentions(inaccessible)

      notify_mentioned_users(to_notify)
      notify_watching_users(except: all_mentioned_user_ids << @user.id)

      to_notify
    end

    def notify_edit
      already_notified_user_ids =
        Notification
          .where(notification_type: Notification.types[:chat_mention])
          .joins(
            "INNER JOIN chat_mention_notifications ON chat_mention_notifications.notification_id = notifications.id",
          )
          .joins(
            "INNER JOIN chat_mentions ON chat_mentions.id = chat_mention_notifications.chat_mention_id",
          )
          .where("chat_mentions.chat_message_id = ?", @chat_message.id)
          .pluck(:user_id)

      to_notify, inaccessible, all_mentioned_user_ids = list_users_to_notify
      needs_notification_ids = all_mentioned_user_ids - already_notified_user_ids
      return if needs_notification_ids.blank?

      notify_creator_of_inaccessible_mentions(inaccessible)
      notify_mentioned_users(to_notify, already_notified_user_ids: already_notified_user_ids)

      to_notify
    end

    def list_users_to_notify
      skip_notifications = @parsed_mentions.count > SiteSetting.max_mentions_per_chat_message

      to_notify = {}
      inaccessible = {}
      all_mentioned_user_ids = []

      # The order of these methods is the precedence
      # between different mention types.
      expand_direct_mentions(to_notify, inaccessible, all_mentioned_user_ids, skip_notifications)
      if !skip_notifications
        expand_group_mentions(to_notify, inaccessible, all_mentioned_user_ids)
        expand_here_mention(to_notify, all_mentioned_user_ids)
        expand_global_mention(to_notify, all_mentioned_user_ids)
      end

      filter_users_ignoring_or_muting_creator(to_notify, inaccessible, all_mentioned_user_ids)

      [to_notify, inaccessible, all_mentioned_user_ids]
    end

    private

    def expand_global_mention(to_notify, already_covered_ids)
      has_all_mention = @parsed_mentions.has_global_mention

      if has_all_mention && @chat_channel.allow_channel_wide_mentions
        to_notify[:global_mentions] = @parsed_mentions
          .global_mentions
          .not_suspended
          .where(user_options: { ignore_channel_wide_mention: [false, nil] })
          .where.not(username_lower: @user.username_lower)
          .where.not(id: already_covered_ids)
          .pluck(:id)

        already_covered_ids.concat(to_notify[:global_mentions])
      else
        to_notify[:global_mentions] = []
      end
    end

    def expand_here_mention(to_notify, already_covered_ids)
      has_here_mention = @parsed_mentions.has_here_mention

      if has_here_mention && @chat_channel.allow_channel_wide_mentions
        to_notify[:here_mentions] = @parsed_mentions
          .here_mentions
          .not_suspended
          .where(user_options: { ignore_channel_wide_mention: [false, nil] })
          .where.not(username_lower: @user.username_lower)
          .where.not(id: already_covered_ids)
          .pluck(:id)

        already_covered_ids.concat(to_notify[:here_mentions])
      else
        to_notify[:here_mentions] = []
      end
    end

    def group_users_to_notify(users)
      potential_members, unreachable =
        users.partition { |user| user.guardian.can_join_chat_channel?(@chat_channel) }

      members, welcome_to_join =
        potential_members.partition { |user| @chat_channel.joined_by?(user) }

      {
        members: members || [],
        welcome_to_join: (welcome_to_join || []).select(&:human?),
        unreachable: (unreachable || []).select(&:human?),
      }
    end

    def expand_direct_mentions(to_notify, inaccessible, already_covered_ids, skip)
      if skip
        direct_mentions = []
      else
        direct_mentions =
          @parsed_mentions
            .direct_mentions
            .not_suspended
            .where.not(username_lower: @user.username_lower)
            .where.not(id: already_covered_ids)
      end

      grouped = group_users_to_notify(direct_mentions)

      to_notify[:direct_mentions] = grouped[:members].map(&:id)
      inaccessible[:welcome_to_join] = grouped[:welcome_to_join]
      inaccessible[:unreachable] = grouped[:unreachable]
      already_covered_ids.concat(to_notify[:direct_mentions])
    end

    def expand_group_mentions(to_notify, inaccessible, already_covered_ids)
      return if @parsed_mentions.visible_groups.empty?

      reached_by_group =
        @parsed_mentions
          .group_mentions
          .not_suspended
          .where.not(username_lower: @user.username_lower)
          .where.not(id: already_covered_ids)

      @parsed_mentions.groups_to_mention.each { |g| to_notify[g.name.downcase] = [] }

      grouped = group_users_to_notify(reached_by_group)
      grouped[:members].each do |user|
        # When a user is a member of multiple mentioned groups,
        # the most far to the left should take precedence.
        ordered_group_names =
          @parsed_mentions.parsed_group_mentions &
            @parsed_mentions.groups_to_mention.map { |mg| mg.name.downcase }
        user_group_names = user.groups.map { |ug| ug.name.downcase }
        group_name = ordered_group_names.detect { |gn| user_group_names.include?(gn) }

        to_notify[group_name] << user.id
        already_covered_ids << user.id
      end

      inaccessible[:welcome_to_join] = inaccessible[:welcome_to_join].concat(
        grouped[:welcome_to_join],
      )
      inaccessible[:unreachable] = inaccessible[:unreachable].concat(grouped[:unreachable])
    end

    def notify_creator_of_inaccessible_mentions(inaccessible)
      # Notify when mentioned users can join channel, but don't have a membership
      if inaccessible[:welcome_to_join].any?
        publish_inaccessible_mentions(inaccessible[:welcome_to_join])
      end

      # Notify when mentioned users are not able to access the channel
      # When user does not have permission to see group members, use the group name instead
      if show_group_warning(inaccessible[:unreachable])
        publish_unreachable_group_warning(hidden_member_groups.first.name)
      elsif inaccessible[:unreachable].any?
        publish_unreachable_mentions(inaccessible[:unreachable])
      end

      # Notify when `@all` or `@here` is used when channel has global mentions disabled
      publish_global_mentions_disabled if global_mentions_disabled

      # Notify when groups are mentioned and have mentions disabled
      group_mentions_disabled = @parsed_mentions.groups_with_disabled_mentions.to_a
      publish_group_mentions_disabled(group_mentions_disabled) if group_mentions_disabled.any?

      # Notify when large groups are mentioned, exceeding `max_users_notified_per_group_mention`
      too_many_members = @parsed_mentions.groups_with_too_many_members.to_a
      publish_too_many_members_in_group_mention(too_many_members) if too_many_members.any?
    end

    def hidden_member_groups
      @hidden_member_groups ||=
        @parsed_mentions.groups_to_mention -
          Group.where(id: @parsed_mentions.groups_to_mention.ids).members_visible_groups(@user)
    end

    def show_group_warning(users)
      users.any? { |user| GroupUser.exists?(group: hidden_member_groups, user: user) }
    end

    def publish_inaccessible_mentions(users)
      Chat::Publisher.publish_notice(
        user_id: @user.id,
        channel_id: @chat_channel.id,
        type: "mention_without_membership",
        data: {
          user_ids: users.map(&:id),
          text:
            mention_warning_text(
              single: "chat.mention_warning.without_membership",
              multiple: "chat.mention_warning.without_membership_multiple",
              first_identifier: users.first.username,
              count: users.count,
            ),
          message_id: @chat_message.id,
        },
      )
    end

    def publish_group_mentions_disabled(groups)
      Chat::Publisher.publish_notice(
        user_id: @user.id,
        channel_id: @chat_channel.id,
        text_content:
          mention_warning_text(
            single: "chat.mention_warning.group_mentions_disabled",
            multiple: "chat.mention_warning.group_mentions_disabled_multiple",
            first_identifier: groups.first.name,
            count: groups.count,
          ),
      )
    end

    def publish_global_mentions_disabled
      Chat::Publisher.publish_notice(
        user_id: @user.id,
        channel_id: @chat_channel.id,
        text_content:
          I18n.t("chat.mention_warning.global_mentions_disallowed", locale: @user.effective_locale),
      )
    end

    def publish_unreachable_mentions(users)
      Chat::Publisher.publish_notice(
        user_id: @user.id,
        channel_id: @chat_channel.id,
        text_content:
          mention_warning_text(
            single: "chat.mention_warning.cannot_see",
            multiple: "chat.mention_warning.cannot_see_multiple",
            first_identifier: users.first.username,
            count: users.count,
          ),
      )
    end

    def publish_unreachable_group_warning(group_name)
      Chat::Publisher.publish_notice(
        user_id: @user.id,
        channel_id: @chat_channel.id,
        text_content:
          I18n.t(
            "chat.mention_warning.cannot_see_group",
            group_name: group_name,
            locale: @user.effective_locale,
          ),
      )
    end

    def publish_too_many_members_in_group_mention(groups)
      Chat::Publisher.publish_notice(
        user_id: @user.id,
        channel_id: @chat_channel.id,
        text_content:
          mention_warning_text(
            single: "chat.mention_warning.too_many_members",
            multiple: "chat.mention_warning.too_many_members_multiple",
            first_identifier: groups.first.name,
            count: groups.count,
          ),
      )
    end

    def mention_warning_text(single:, multiple:, first_identifier:, count:)
      translation_key = count == 1 ? single : multiple
      I18n.t(
        translation_key,
        first_identifier: first_identifier,
        count: count - 1,
        locale: @user.effective_locale,
      )
    end

    def global_mentions_disabled
      return @global_mentions_disabled if defined?(@global_mentions_disabled)

      @global_mentions_disabled =
        (@parsed_mentions.has_global_mention || @parsed_mentions.has_here_mention) &&
          !@chat_channel.allow_channel_wide_mentions
      @global_mentions_disabled
    end

    # Filters out users from global, here, group, and direct mentions that are
    # ignoring or muting the creator of the message, so they will not receive
    # a notification via the Jobs::Chat::NotifyMentioned job and are not prompted for
    # invitation by the creator.
    def filter_users_ignoring_or_muting_creator(to_notify, inaccessible, already_covered_ids)
      screen_targets = already_covered_ids.concat(inaccessible[:welcome_to_join].map(&:id))

      return if screen_targets.blank?

      screener = UserCommScreener.new(acting_user: @user, target_user_ids: screen_targets)
      to_notify.each do |key, user_ids|
        to_notify[key] = user_ids.reject { |user_id| screener.ignoring_or_muting_actor?(user_id) }
      end

      # :welcome_to_join contains users because it's serialized by MB.
      inaccessible[:welcome_to_join] = inaccessible[:welcome_to_join].reject do |user|
        screener.ignoring_or_muting_actor?(user.id)
      end

      already_covered_ids.reject! do |already_covered|
        screener.ignoring_or_muting_actor?(already_covered)
      end
    end

    def notify_mentioned_users(to_notify, already_notified_user_ids: [])
      Jobs.enqueue(
        Jobs::Chat::NotifyMentioned,
        {
          chat_message_id: @chat_message.id,
          to_notify_ids_map: to_notify.as_json,
          already_notified_user_ids: already_notified_user_ids,
          timestamp: @timestamp.to_s,
        },
      )
    end

    def notify_watching_users(except: [])
      Jobs.enqueue_in(
        5.seconds,
        Jobs::Chat::NotifyWatching,
        { chat_message_id: @chat_message.id, except_user_ids: except, timestamp: @timestamp.to_s },
      )
    end
  end
end
