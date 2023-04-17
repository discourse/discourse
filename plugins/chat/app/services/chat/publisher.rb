# frozen_string_literal: true

module Chat
  module Publisher
    def self.new_messages_message_bus_channel(chat_channel_id)
      "/chat/#{chat_channel_id}/new-messages"
    end

    def self.root_message_bus_channel(chat_channel_id)
      "/chat/#{chat_channel_id}"
    end

    def self.thread_message_bus_channel(chat_channel_id, thread_id)
      "#{root_message_bus_channel(chat_channel_id)}/thread/#{thread_id}"
    end

    def self.calculate_publish_targets(channel, message)
      targets =
        if message.thread_om?
          [
            root_message_bus_channel(channel.id),
            thread_message_bus_channel(channel.id, message.thread_id),
          ]
        elsif message.thread_reply?
          [thread_message_bus_channel(channel.id, message.thread_id)]
        else
          [root_message_bus_channel(channel.id)]
        end
      targets
    end

    def self.publish_new!(chat_channel, chat_message, staged_id)
      message_bus_targets = calculate_publish_targets(chat_channel, chat_message)

      content =
        Chat::MessageSerializer.new(
          chat_message,
          { scope: anonymous_guardian, root: :chat_message },
        ).as_json
      content[:type] = :sent
      content[:staged_id] = staged_id
      permissions = permissions(chat_channel)

      message_bus_targets.each do |message_bus_channel|
        MessageBus.publish(message_bus_channel, content.as_json, permissions)
      end

      # NOTE: This means that the read count is only updated in the client
      # for new messages in the main channel stream, maybe in future we want to
      # do this for thread messages as well?
      if !chat_message.thread_reply?
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
    end

    def self.publish_thread_original_message_metadata!(thread)
      permissions = permissions(thread.channel)
      MessageBus.publish(
        root_message_bus_channel(thread.channel.id),
        {
          type: :update_thread_original_message,
          original_message_id: thread.original_message_id,
          replies_count: thread.replies_count_cache,
        }.as_json,
        permissions,
      )
    end

    def self.publish_thread_created!(chat_channel, chat_message)
      content =
        Chat::MessageSerializer.new(
          chat_message,
          { scope: anonymous_guardian, root: :chat_message },
        ).as_json
      content[:type] = :thread_created
      permissions = permissions(chat_channel)

      MessageBus.publish(root_message_bus_channel(chat_channel.id), content.as_json, permissions)
    end

    def self.publish_processed!(chat_message)
      chat_channel = chat_message.chat_channel
      message_bus_targets = calculate_publish_targets(chat_channel, chat_message)

      content = {
        type: :processed,
        chat_message: {
          id: chat_message.id,
          cooked: chat_message.cooked,
        },
      }

      message_bus_targets.each do |message_bus_channel|
        MessageBus.publish(message_bus_channel, content.as_json, permissions(chat_channel))
      end
    end

    def self.publish_edit!(chat_channel, chat_message)
      message_bus_targets = calculate_publish_targets(chat_channel, chat_message)

      content =
        Chat::MessageSerializer.new(
          chat_message,
          { scope: anonymous_guardian, root: :chat_message },
        ).as_json
      content[:type] = :edit

      message_bus_targets.each do |message_bus_channel|
        MessageBus.publish(message_bus_channel, content.as_json, permissions(chat_channel))
      end
    end

    def self.publish_refresh!(chat_channel, chat_message)
      message_bus_targets = calculate_publish_targets(chat_channel, chat_message)

      content =
        Chat::MessageSerializer.new(
          chat_message,
          { scope: anonymous_guardian, root: :chat_message },
        ).as_json
      content[:type] = :refresh

      message_bus_targets.each do |message_bus_channel|
        MessageBus.publish(message_bus_channel, content.as_json, permissions(chat_channel))
      end
    end

    def self.publish_reaction!(chat_channel, chat_message, action, user, emoji)
      message_bus_targets = calculate_publish_targets(chat_channel, chat_message)

      content = {
        action: action,
        user: BasicUserSerializer.new(user, root: false).as_json,
        emoji: emoji,
        type: :reaction,
        chat_message_id: chat_message.id,
      }

      message_bus_targets.each do |message_bus_channel|
        MessageBus.publish(message_bus_channel, content.as_json, permissions(chat_channel))
      end
    end

    def self.publish_presence!(chat_channel, user, typ)
      raise NotImplementedError
    end

    def self.publish_delete!(chat_channel, chat_message)
      message_bus_targets = calculate_publish_targets(chat_channel, chat_message)

      message_bus_targets.each do |message_bus_channel|
        MessageBus.publish(
          message_bus_channel,
          { type: "delete", deleted_id: chat_message.id, deleted_at: chat_message.deleted_at },
          permissions(chat_channel),
        )
      end
    end

    def self.publish_bulk_delete!(chat_channel, deleted_message_ids)
      Chat::Thread
        .grouped_messages(message_ids: deleted_message_ids)
        .each do |group|
          MessageBus.publish(
            thread_message_bus_channel(chat_channel.id, group.thread_id),
            {
              type: "bulk_delete",
              deleted_ids: group.thread_message_ids,
              deleted_at: Time.zone.now,
            },
            permissions(chat_channel),
          )

          # Don't need to publish to the main channel if the messages deleted
          # were a part of the thread (except the original message ID, since
          # that shows in the main channel).
          deleted_message_ids =
            deleted_message_ids - (group.thread_message_ids - [group.original_message_id])
        end

      return if deleted_message_ids.empty?

      MessageBus.publish(
        root_message_bus_channel(chat_channel.id),
        { type: "bulk_delete", deleted_ids: deleted_message_ids, deleted_at: Time.zone.now },
        permissions(chat_channel),
      )
    end

    def self.publish_restore!(chat_channel, chat_message)
      message_bus_targets = calculate_publish_targets(chat_channel, chat_message)

      content =
        Chat::MessageSerializer.new(
          chat_message,
          { scope: anonymous_guardian, root: :chat_message },
        ).as_json
      content[:type] = :restore

      message_bus_targets.each do |message_bus_channel|
        MessageBus.publish(message_bus_channel, content.as_json, permissions(chat_channel))
      end
    end

    def self.publish_flag!(chat_message, user, reviewable, score)
      message_bus_targets = calculate_publish_targets(chat_message.chat_channel, chat_message)

      message_bus_targets.each do |message_bus_channel|
        # Publish to user who created flag
        MessageBus.publish(
          message_bus_channel,
          {
            type: "self_flagged",
            user_flag_status: score.status_for_database,
            chat_message_id: chat_message.id,
          }.as_json,
          user_ids: [user.id],
        )
      end

      message_bus_targets.each do |message_bus_channel|
        # Publish flag with link to reviewable to staff
        MessageBus.publish(
          message_bus_channel,
          { type: "flag", chat_message_id: chat_message.id, reviewable_id: reviewable.id }.as_json,
          group_ids: [Group::AUTO_GROUPS[:staff]],
        )
      end
    end

    def self.user_tracking_state_message_bus_channel(user_id)
      "/chat/user-tracking-state/#{user_id}"
    end

    def self.publish_user_tracking_state(user, chat_channel_id, chat_message_id)
      data = {
        channel_id: chat_channel_id,
        last_read_message_id: chat_message_id,
        # TODO (martin) Remove old chat_channel_id and chat_message_id keys here once deploys have cycled,
        # this will prevent JS errors from clients that are looking for the old payload.
        chat_channel_id: chat_channel_id,
        chat_message_id: chat_message_id,
      }.merge(
        Chat::ChannelUnreadsQuery.call(channel_ids: [chat_channel_id], user_id: user.id).first.to_h,
      )

      MessageBus.publish(
        self.user_tracking_state_message_bus_channel(user.id),
        data.as_json,
        user_ids: [user.id],
      )
    end

    def self.bulk_user_tracking_state_message_bus_channel(user_id)
      "/chat/bulk-user-tracking-state/#{user_id}"
    end

    def self.publish_bulk_user_tracking_state(user, channel_last_read_map)
      unread_data =
        Chat::ChannelUnreadsQuery.call(
          channel_ids: channel_last_read_map.keys,
          user_id: user.id,
        ).map(&:to_h)

      channel_last_read_map.each do |key, value|
        channel_last_read_map[key] = value.merge(
          unread_data.find { |data| data[:channel_id] == key }.except(:channel_id),
        )
      end

      MessageBus.publish(
        self.bulk_user_tracking_state_message_bus_channel(user.id),
        channel_last_read_map.as_json,
        user_ids: [user.id],
      )
    end

    def self.new_mentions_message_bus_channel(chat_channel_id)
      "/chat/#{chat_channel_id}/new-mentions"
    end

    def self.kick_users_message_bus_channel(chat_channel_id)
      "/chat/#{chat_channel_id}/kick"
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
          Chat::ChannelSerializer.new(
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
      MessageBus.publish(
        kick_users_message_bus_channel(channel_id),
        { channel_id: channel_id },
        user_ids: user_ids,
      )
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
end
