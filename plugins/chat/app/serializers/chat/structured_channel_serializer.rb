# frozen_string_literal: true

module Chat
  class StructuredChannelSerializer < ApplicationSerializer
    attributes :public_channels, :direct_message_channels, :tracking, :meta, :unread_thread_overview

    def tracking
      object[:tracking]
    end

    def include_unread_thread_overview?
      SiteSetting.enable_experimental_chat_threaded_discussions
    end

    def unread_thread_overview
      object[:unread_thread_overview]
    end

    def public_channels
      object[:public_channels].map do |channel|
        Chat::ChannelSerializer.new(
          channel,
          root: nil,
          scope: scope,
          membership: channel_membership(channel.id),
          new_messages_message_bus_last_id:
            chat_message_bus_last_ids[Chat::Publisher.new_messages_message_bus_channel(channel.id)],
          new_mentions_message_bus_last_id:
            chat_message_bus_last_ids[Chat::Publisher.new_mentions_message_bus_channel(channel.id)],
          kick_message_bus_last_id:
            chat_message_bus_last_ids[Chat::Publisher.kick_users_message_bus_channel(channel.id)],
          channel_message_bus_last_id:
            chat_message_bus_last_ids[Chat::Publisher.root_message_bus_channel(channel.id)],
          # NOTE: This is always true because the public channels passed into this serializer
          # have been fetched with [Chat::ChannelFetcher], which only returns channels that
          # the user has access to based on category permissions.
          can_join_chat_channel: true,
        )
      end
    end

    def direct_message_channels
      object[:direct_message_channels].map do |channel|
        Chat::ChannelSerializer.new(
          channel,
          root: nil,
          scope: scope,
          membership: channel_membership(channel.id),
          new_messages_message_bus_last_id:
            chat_message_bus_last_ids[Chat::Publisher.new_messages_message_bus_channel(channel.id)],
          new_mentions_message_bus_last_id:
            chat_message_bus_last_ids[Chat::Publisher.new_mentions_message_bus_channel(channel.id)],
          channel_message_bus_last_id:
            chat_message_bus_last_ids[Chat::Publisher.root_message_bus_channel(channel.id)],
        )
      end
    end

    def channel_membership(channel_id)
      return if scope.anonymous?
      object[:memberships].find { |membership| membership.chat_channel_id == channel_id }
    end

    def meta
      last_ids = {
        channel_metadata:
          chat_message_bus_last_ids[Chat::Publisher::CHANNEL_METADATA_MESSAGE_BUS_CHANNEL],
        channel_edits:
          chat_message_bus_last_ids[Chat::Publisher::CHANNEL_EDITS_MESSAGE_BUS_CHANNEL],
        channel_status:
          chat_message_bus_last_ids[Chat::Publisher::CHANNEL_STATUS_MESSAGE_BUS_CHANNEL],
        new_channel: chat_message_bus_last_ids[Chat::Publisher::NEW_CHANNEL_MESSAGE_BUS_CHANNEL],
        archive_status:
          chat_message_bus_last_ids[Chat::Publisher::CHANNEL_ARCHIVE_STATUS_MESSAGE_BUS_CHANNEL],
      }

      if !scope.anonymous?
        user_tracking_state_last_id =
          chat_message_bus_last_ids[
            Chat::Publisher.user_tracking_state_message_bus_channel(scope.user.id)
          ]

        last_ids[:user_tracking_state] = user_tracking_state_last_id if user_tracking_state_last_id
      end

      { message_bus_last_ids: last_ids }
    end

    private

    def chat_message_bus_last_ids
      @chat_message_bus_last_ids ||=
        begin
          message_bus_channels = [
            Chat::Publisher::CHANNEL_METADATA_MESSAGE_BUS_CHANNEL,
            Chat::Publisher::CHANNEL_EDITS_MESSAGE_BUS_CHANNEL,
            Chat::Publisher::CHANNEL_STATUS_MESSAGE_BUS_CHANNEL,
            Chat::Publisher::NEW_CHANNEL_MESSAGE_BUS_CHANNEL,
            Chat::Publisher::CHANNEL_ARCHIVE_STATUS_MESSAGE_BUS_CHANNEL,
          ]

          if !scope.anonymous?
            message_bus_channels.push(
              Chat::Publisher.user_tracking_state_message_bus_channel(scope.user.id),
            )
          end

          object[:public_channels].each do |channel|
            message_bus_channels.push(Chat::Publisher.new_messages_message_bus_channel(channel.id))
            message_bus_channels.push(Chat::Publisher.new_mentions_message_bus_channel(channel.id))
            message_bus_channels.push(Chat::Publisher.kick_users_message_bus_channel(channel.id))
            message_bus_channels.push(Chat::Publisher.root_message_bus_channel(channel.id))
          end

          object[:direct_message_channels].each do |channel|
            message_bus_channels.push(Chat::Publisher.new_messages_message_bus_channel(channel.id))
            message_bus_channels.push(Chat::Publisher.new_mentions_message_bus_channel(channel.id))
            message_bus_channels.push(Chat::Publisher.root_message_bus_channel(channel.id))
          end

          MessageBus.last_ids(*message_bus_channels)
        end
    end
  end
end
