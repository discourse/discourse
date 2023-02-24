# frozen_string_literal: true

module ChatPublisher
  def self.new_messages_message_bus_channel(chat_channel_id)
    "/chat/#{chat_channel_id}/new-messages"
  end

  def self.publish_new!(chat_channel, chat_message, staged_id)
    content =
      ChatMessageSerializer.new(
        chat_message,
        { scope: anonymous_guardian, root: :chat_message },
      ).as_json
    content[:type] = :sent
    content[:stagedId] = staged_id
    permissions = permissions(chat_channel)

    MessageBus.publish("/chat/#{chat_channel.id}", content.as_json, permissions)

    MessageBus.publish(
      self.new_messages_message_bus_channel(chat_channel.id),
      {
        channel_id: chat_channel.id,
        message_id: chat_message.id,
        user_id: chat_message.user.id,
        username: chat_message.user.username,
        thread_id: chat_message.thread_id,
      },
      permissions,
    )
  end

  def self.publish_processed!(chat_message)
    chat_channel = chat_message.chat_channel
    content = {
      type: :processed,
      chat_message: {
        id: chat_message.id,
        cooked: chat_message.cooked,
      },
    }
    MessageBus.publish("/chat/#{chat_channel.id}", content.as_json, permissions(chat_channel))
  end

  def self.publish_edit!(chat_channel, chat_message)
    content =
      ChatMessageSerializer.new(
        chat_message,
        { scope: anonymous_guardian, root: :chat_message },
      ).as_json
    content[:type] = :edit
    MessageBus.publish("/chat/#{chat_channel.id}", content.as_json, permissions(chat_channel))
  end

  def self.publish_refresh!(chat_channel, chat_message)
    content =
      ChatMessageSerializer.new(
        chat_message,
        { scope: anonymous_guardian, root: :chat_message },
      ).as_json
    content[:type] = :refresh
    MessageBus.publish("/chat/#{chat_channel.id}", content.as_json, permissions(chat_channel))
  end

  def self.publish_reaction!(chat_channel, chat_message, action, user, emoji)
    content = {
      action: action,
      user: BasicUserSerializer.new(user, root: false).as_json,
      emoji: emoji,
      type: :reaction,
      chat_message_id: chat_message.id,
    }
    MessageBus.publish(
      "/chat/message-reactions/#{chat_message.id}",
      content.as_json,
      permissions(chat_channel),
    )
    MessageBus.publish("/chat/#{chat_channel.id}", content.as_json, permissions(chat_channel))
  end

  def self.publish_presence!(chat_channel, user, typ)
    raise NotImplementedError
  end

  def self.publish_delete!(chat_channel, chat_message)
    MessageBus.publish(
      "/chat/#{chat_channel.id}",
      { type: "delete", deleted_id: chat_message.id, deleted_at: chat_message.deleted_at },
      permissions(chat_channel),
    )
  end

  def self.publish_bulk_delete!(chat_channel, deleted_message_ids)
    MessageBus.publish(
      "/chat/#{chat_channel.id}",
      { typ: "bulk_delete", deleted_ids: deleted_message_ids, deleted_at: Time.zone.now },
      permissions(chat_channel),
    )
  end

  def self.publish_restore!(chat_channel, chat_message)
    content =
      ChatMessageSerializer.new(
        chat_message,
        { scope: anonymous_guardian, root: :chat_message },
      ).as_json
    content[:type] = :restore
    MessageBus.publish("/chat/#{chat_channel.id}", content.as_json, permissions(chat_channel))
  end

  def self.publish_flag!(chat_message, user, reviewable, score)
    # Publish to user who created flag
    MessageBus.publish(
      "/chat/#{chat_message.chat_channel_id}",
      {
        type: "self_flagged",
        user_flag_status: score.status_for_database,
        chat_message_id: chat_message.id,
      }.as_json,
      user_ids: [user.id],
    )

    # Publish flag with link to reviewable to staff
    MessageBus.publish(
      "/chat/#{chat_message.chat_channel_id}",
      { type: "flag", chat_message_id: chat_message.id, reviewable_id: reviewable.id }.as_json,
      group_ids: [Group::AUTO_GROUPS[:staff]],
    )
  end

  def self.user_tracking_state_message_bus_channel(user_id)
    "/chat/user-tracking-state/#{user_id}"
  end

  def self.publish_user_tracking_state(user, chat_channel_id, chat_message_id)
    MessageBus.publish(
      self.user_tracking_state_message_bus_channel(user.id),
      { chat_channel_id: chat_channel_id, chat_message_id: chat_message_id.to_i }.as_json,
      user_ids: [user.id],
    )
  end

  def self.new_mentions_message_bus_channel(chat_channel_id)
    "/chat/#{chat_channel_id}/new-mentions"
  end

  def self.publish_new_mention(user_id, chat_channel_id, chat_message_id)
    MessageBus.publish(
      self.new_mentions_message_bus_channel(chat_channel_id),
      { message_id: chat_message_id, channel_id: chat_channel_id }.as_json,
      user_ids: [user_id],
    )
  end

  NEW_CHANNEL_MESSAGE_BUS_CHANNEL = "/chat/new-channel"

  def self.publish_new_channel(chat_channel, users)
    users.each do |user|
      # FIXME: This could generate a lot of queries depending on the amount of users
      membership = chat_channel.membership_for(user)

      # TODO: this event is problematic as some code will update the membership before calling it
      # and other code will update it after calling it
      # it means frontend must handle logic for both cases
      serialized_channel =
        ChatChannelSerializer.new(
          chat_channel,
          scope: Guardian.new(user), # We need a guardian here for direct messages
          root: :channel,
          membership: membership,
        ).as_json

      MessageBus.publish(NEW_CHANNEL_MESSAGE_BUS_CHANNEL, serialized_channel, user_ids: [user.id])
    end
  end

  def self.publish_inaccessible_mentions(
    user_id,
    chat_message,
    cannot_chat_users,
    without_membership,
    too_many_members,
    mentions_disabled
  )
    MessageBus.publish(
      "/chat/#{chat_message.chat_channel_id}",
      {
        type: :mention_warning,
        chat_message_id: chat_message.id,
        cannot_see: cannot_chat_users.map { |u| { username: u.username, id: u.id } }.as_json,
        without_membership:
          without_membership.map { |u| { username: u.username, id: u.id } }.as_json,
        groups_with_too_many_members: too_many_members.map(&:name).as_json,
        group_mentions_disabled: mentions_disabled.map(&:name).as_json,
      },
      user_ids: [user_id],
    )
  end

  def self.publish_kick_users(channel_id, user_ids)
    MessageBus.publish("/chat/kick/#{channel_id}", nil, user_ids: user_ids)
  end

  CHANNEL_EDITS_MESSAGE_BUS_CHANNEL = "/chat/channel-edits"

  def self.publish_chat_channel_edit(chat_channel, acting_user)
    MessageBus.publish(
      CHANNEL_EDITS_MESSAGE_BUS_CHANNEL,
      {
        chat_channel_id: chat_channel.id,
        name: chat_channel.title(acting_user),
        description: chat_channel.description,
        slug: chat_channel.slug,
      },
      permissions(chat_channel),
    )
  end

  CHANNEL_STATUS_MESSAGE_BUS_CHANNEL = "/chat/channel-status"

  def self.publish_channel_status(chat_channel)
    MessageBus.publish(
      CHANNEL_STATUS_MESSAGE_BUS_CHANNEL,
      { chat_channel_id: chat_channel.id, status: chat_channel.status },
      permissions(chat_channel),
    )
  end

  CHANNEL_METADATA_MESSAGE_BUS_CHANNEL = "/chat/channel-metadata"

  def self.publish_chat_channel_metadata(chat_channel)
    MessageBus.publish(
      CHANNEL_METADATA_MESSAGE_BUS_CHANNEL,
      { chat_channel_id: chat_channel.id, memberships_count: chat_channel.user_count },
      permissions(chat_channel),
    )
  end

  CHANNEL_ARCHIVE_STATUS_MESSAGE_BUS_CHANNEL = "/chat/channel-archive-status"

  def self.publish_archive_status(
    chat_channel,
    archive_status:,
    archived_messages:,
    archive_topic_id:,
    total_messages:
  )
    MessageBus.publish(
      CHANNEL_ARCHIVE_STATUS_MESSAGE_BUS_CHANNEL,
      {
        chat_channel_id: chat_channel.id,
        archive_failed: archive_status == :failed,
        archive_completed: archive_status == :success,
        archived_messages: archived_messages,
        total_messages: total_messages,
        archive_topic_id: archive_topic_id,
      },
      permissions(chat_channel),
    )
  end

  private

  def self.permissions(chat_channel)
    { user_ids: chat_channel.allowed_user_ids, group_ids: chat_channel.allowed_group_ids }
  end

  def self.anonymous_guardian
    Guardian.new(nil)
  end
end
