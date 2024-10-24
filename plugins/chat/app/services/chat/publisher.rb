# frozen_string_literal: true

module Chat
  module Publisher
    def self.new_messages_message_bus_channel(chat_channel_id)
      "#{root_message_bus_channel(chat_channel_id)}/new-messages"
    end

    def self.root_message_bus_channel(chat_channel_id)
      "/chat/#{chat_channel_id}"
    end

    def self.thread_message_bus_channel(chat_channel_id, thread_id)
      "#{root_message_bus_channel(chat_channel_id)}/thread/#{thread_id}"
    end

    def self.calculate_publish_targets(channel, message)
      return [root_message_bus_channel(channel.id)] if !allow_publish_to_thread?(channel, message)

      if message.thread_om?
        [
          root_message_bus_channel(channel.id),
          thread_message_bus_channel(channel.id, message.thread_id),
        ]
      elsif message.thread_reply?
        targets = [thread_message_bus_channel(channel.id, message.thread_id)]
        targets
      else
        [root_message_bus_channel(channel.id)]
      end
    end

    def self.allow_publish_to_thread?(channel, message)
      channel.threading_enabled || message.thread&.force
    end

    def self.publish_new!(chat_channel, chat_message, staged_id)
      message_bus_targets = calculate_publish_targets(chat_channel, chat_message)
      publish_to_targets!(
        message_bus_targets,
        chat_channel,
        serialize_message_with_type(chat_message, :sent).merge(staged_id: staged_id),
      )

      if !chat_message.thread_reply? || !allow_publish_to_thread?(chat_channel, chat_message)
        MessageBus.publish(
          self.new_messages_message_bus_channel(chat_channel.id),
          {
            type: "channel",
            channel_id: chat_channel.id,
            thread_id: chat_message.thread_id,
            message:
              Chat::MessageSerializer.new(
                chat_message,
                { scope: anonymous_guardian, root: false },
              ).as_json,
          },
          permissions(chat_channel),
        )
      end

      if chat_message.thread_reply? && allow_publish_to_thread?(chat_channel, chat_message)
        MessageBus.publish(
          self.new_messages_message_bus_channel(chat_channel.id),
          {
            type: "thread",
            channel_id: chat_channel.id,
            thread_id: chat_message.thread_id,
            force_thread: chat_message.thread&.force,
            message:
              Chat::MessageSerializer.new(
                chat_message,
                { scope: anonymous_guardian, root: false },
              ).as_json,
          },
          permissions(chat_channel),
        )

        publish_thread_original_message_metadata!(chat_message.thread)
      end
    end

    def self.publish_thread_original_message_metadata!(thread)
      preview =
        ::Chat::ThreadPreviewSerializer.new(
          thread,
          participants: ::Chat::ThreadParticipantQuery.call(thread_ids: [thread.id])[thread.id],
          root: false,
        ).as_json
      publish_to_channel!(
        thread.channel,
        {
          type: :update_thread_original_message,
          original_message_id: thread.original_message_id,
          thread_id: thread.id,
          channel_id: thread.channel.id,
          preview: preview.as_json,
        },
      )
    end

    def self.publish_thread_created!(chat_channel, chat_message, thread_id)
      publish_to_channel!(
        chat_channel,
        serialize_message_with_type(chat_message, :thread_created, { thread_id: thread_id }),
      )
    end

    def self.publish_processed!(chat_message)
      chat_channel = chat_message.chat_channel
      message_bus_targets = calculate_publish_targets(chat_channel, chat_message)
      publish_to_targets!(
        message_bus_targets,
        chat_channel,
        serialize_message_with_type(chat_message, :processed),
      )
    end

    def self.publish_edit!(chat_channel, chat_message)
      message_bus_targets = calculate_publish_targets(chat_channel, chat_message)
      publish_to_targets!(
        message_bus_targets,
        chat_channel,
        serialize_message_with_type(chat_message, :edit),
      )
    end

    def self.publish_refresh!(chat_channel, chat_message)
      message_bus_targets = calculate_publish_targets(chat_channel, chat_message)
      publish_to_targets!(
        message_bus_targets,
        chat_channel,
        serialize_message_with_type(chat_message, :refresh),
      )
    end

    def self.publish_reaction!(chat_channel, chat_message, action, user, emoji)
      message_bus_targets = calculate_publish_targets(chat_channel, chat_message)
      publish_to_targets!(
        message_bus_targets,
        chat_channel,
        {
          action: action,
          user: BasicUserSerializer.new(user, root: false).as_json,
          emoji: emoji,
          type: :reaction,
          chat_message_id: chat_message.id,
        },
      )
    end

    def self.publish_presence!(chat_channel, user, typ)
      raise NotImplementedError
    end

    def self.publish_delete!(chat_channel, chat_message)
      message_bus_targets = calculate_publish_targets(chat_channel, chat_message)
      latest_not_deleted_message_id =
        if chat_message.thread_reply? && chat_channel.threading_enabled
          chat_message.thread.latest_not_deleted_message_id(anchor_message_id: chat_message.id)
        else
          chat_channel.latest_not_deleted_message_id(anchor_message_id: chat_message.id)
        end
      publish_to_targets!(
        message_bus_targets,
        chat_channel,
        {
          type: "delete",
          deleted_id: chat_message.id,
          deleted_at: chat_message.deleted_at,
          deleted_by_id: chat_message.deleted_by_id,
          latest_not_deleted_message_id: latest_not_deleted_message_id,
        },
      )
    end

    def self.publish_bulk_delete!(chat_channel, deleted_message_ids)
      channel_permissions = permissions(chat_channel)
      Chat::Thread
        .grouped_messages(message_ids: deleted_message_ids)
        .each do |group|
          MessageBus.publish(
            thread_message_bus_channel(chat_channel.id, group.thread_id),
            {
              type: :bulk_delete,
              deleted_ids: group.thread_message_ids,
              deleted_at: Time.zone.now,
            },
            channel_permissions,
          )

          # Don't need to publish to the main channel if the messages deleted
          # were a part of the thread (except the original message ID, since
          # that shows in the main channel).
          deleted_message_ids =
            deleted_message_ids - (group.thread_message_ids - [group.original_message_id])
        end

      return if deleted_message_ids.empty?

      publish_to_channel!(
        chat_channel,
        { type: :bulk_delete, deleted_ids: deleted_message_ids, deleted_at: Time.zone.now },
      )
    end

    def self.publish_restore!(chat_channel, chat_message)
      message_bus_targets = calculate_publish_targets(chat_channel, chat_message)
      publish_to_targets!(
        message_bus_targets,
        chat_channel,
        serialize_message_with_type(chat_message, :restore),
      )
    end

    def self.publish_flag!(chat_message, user, reviewable, score)
      message_bus_targets = calculate_publish_targets(chat_message.chat_channel, chat_message)

      # Publish to user who created flag
      publish_to_targets!(
        message_bus_targets,
        chat_message.chat_channel,
        {
          type: :self_flagged,
          user_flag_status: score.status_for_database,
          chat_message_id: chat_message.id,
        },
        permissions: {
          user_ids: [user.id],
        },
      )

      # Publish flag with link to reviewable to staff
      publish_to_targets!(
        message_bus_targets,
        chat_message.chat_channel,
        { type: :flag, chat_message_id: chat_message.id, reviewable_id: reviewable.id },
        permissions: {
          group_ids: [Group::AUTO_GROUPS[:staff]],
        },
      )
    end

    def self.publish_to_channel!(channel, payload)
      MessageBus.publish(
        root_message_bus_channel(channel.id),
        payload.as_json,
        permissions(channel),
      )
    end

    def self.publish_to_targets!(targets, channel, payload, permissions: nil)
      targets.each do |message_bus_channel|
        MessageBus.publish(
          message_bus_channel,
          payload.as_json,
          permissions || permissions(channel),
        )
      end
    end

    def self.serialize_message_with_type(chat_message, type, options = {})
      Chat::MessageSerializer
        .new(chat_message, { scope: anonymous_guardian, root: :chat_message })
        .as_json
        .merge(type: type)
        .merge(options)
    end

    def self.user_tracking_state_message_bus_channel(user_id)
      "/chat/user-tracking-state/#{user_id}"
    end

    def self.publish_user_tracking_state!(user, channel, message)
      data = {
        channel_id: channel.id,
        last_read_message_id: message.id,
        thread_id: message.thread_id,
      }

      channel_tracking_data =
        Chat::TrackingStateReportQuery.call(
          guardian: user.guardian,
          channel_ids: [channel.id],
          include_missing_memberships: true,
        ).find_channel(channel.id)

      data.merge!(channel_tracking_data)

      # Need the thread unread overview if channel has threading enabled
      # and a message is sent in the thread. We also need to pass the actual
      # thread tracking state.
      if channel.threading_enabled && message.thread_reply?
        data[:unread_thread_overview] = ::Chat::TrackingStateReportQuery.call(
          guardian: user.guardian,
          channel_ids: [channel.id],
          include_threads: true,
          include_read: false,
          include_last_reply_details: true,
        ).find_channel_thread_overviews(channel.id)

        data[:thread_tracking] = ::Chat::TrackingStateReportQuery.call(
          guardian: user.guardian,
          thread_ids: [message.thread_id],
          include_threads: true,
          include_missing_memberships: true,
        ).find_thread(message.thread_id)
      end

      MessageBus.publish(
        self.user_tracking_state_message_bus_channel(user.id),
        data.as_json,
        user_ids: [user.id],
      )
    end

    def self.bulk_user_tracking_state_message_bus_channel(user_id)
      "/chat/bulk-user-tracking-state/#{user_id}"
    end

    def self.publish_bulk_user_tracking_state!(user, channel_last_read_map)
      tracking_data =
        Chat::TrackingState.call(
          guardian: Guardian.new(user),
          params: {
            channel_ids: channel_last_read_map.keys,
            include_missing_memberships: true,
          },
        )
      if tracking_data.failure?
        raise StandardError,
              "Tracking service failed when trying to publish bulk tracking state:\n\n#{tracking_data.inspect_steps}"
      end

      channel_last_read_map.each do |key, value|
        channel_last_read_map[key] = value.merge(tracking_data.report.find_channel(key))
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
      Chat::UserChatChannelMembership
        .includes(:user)
        .where(chat_channel: chat_channel, user: users)
        .find_in_batches do |memberships|
          memberships.each do |membership|
            serialized_channel =
              Chat::ChannelSerializer.new(
                chat_channel,
                scope: membership.user.guardian, # We need a guardian here for direct messages
                root: :channel,
                membership: membership,
              ).as_json

            MessageBus.publish(
              NEW_CHANNEL_MESSAGE_BUS_CHANNEL,
              serialized_channel,
              user_ids: [membership.user.id],
            )
          end
        end
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

    def self.publish_notice(user_id:, channel_id:, text_content: nil, type: nil, data: nil)
      # Notices are either plain text sent to the client, or a "type" with data. The
      # client will then translate that type and data into a front-end component.
      if text_content.blank? && type.blank? && data.blank?
        raise "Cannot publish notice without text content or a type"
      end
      payload = { type: "notice", channel_id: channel_id }
      if text_content
        payload[:text_content] = text_content
      else
        payload[:notice_type] = type
        payload[:data] = data
      end

      MessageBus.publish("/chat/#{channel_id}", payload, user_ids: [user_id])
    end

    private

    def self.permissions(channel)
      {
        user_ids: channel.allowed_user_ids.presence,
        group_ids: channel.allowed_group_ids.presence,
      }.compact
    end

    def self.anonymous_guardian
      Guardian.new(nil)
    end
  end
end
