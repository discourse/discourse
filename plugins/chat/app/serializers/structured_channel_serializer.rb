# frozen_string_literal: true

class StructuredChannelSerializer < ApplicationSerializer
  attributes :public_channels, :direct_message_channels, :meta

  def public_channels
    object[:public_channels].map do |channel|
      ChatChannelSerializer.new(
        channel,
        root: nil,
        scope: scope,
        membership: channel_membership(channel.id),
        new_messages_message_bus_last_id:
          chat_message_bus_last_ids[ChatPublisher.new_messages_message_bus_channel(channel.id)],
        new_mentions_message_bus_last_id:
          chat_message_bus_last_ids[ChatPublisher.new_mentions_message_bus_channel(channel.id)],
      )
    end
  end

  def direct_message_channels
    object[:direct_message_channels].map do |channel|
      ChatChannelSerializer.new(
        channel,
        root: nil,
        scope: scope,
        membership: channel_membership(channel.id),
        new_messages_message_bus_last_id:
          chat_message_bus_last_ids[ChatPublisher.new_messages_message_bus_channel(channel.id)],
        new_mentions_message_bus_last_id:
          chat_message_bus_last_ids[ChatPublisher.new_mentions_message_bus_channel(channel.id)],
        kick_message_bus_last_id:
          chat_message_bus_last_ids[ChatPublisher.kick_users_message_bus_channel(channel.id)],
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
        chat_message_bus_last_ids[ChatPublisher::CHANNEL_METADATA_MESSAGE_BUS_CHANNEL],
      channel_edits: chat_message_bus_last_ids[ChatPublisher::CHANNEL_EDITS_MESSAGE_BUS_CHANNEL],
      channel_status: chat_message_bus_last_ids[ChatPublisher::CHANNEL_STATUS_MESSAGE_BUS_CHANNEL],
      new_channel: chat_message_bus_last_ids[ChatPublisher::NEW_CHANNEL_MESSAGE_BUS_CHANNEL],
      archive_status:
        chat_message_bus_last_ids[ChatPublisher::CHANNEL_ARCHIVE_STATUS_MESSAGE_BUS_CHANNEL],
    }

    if id =
         chat_message_bus_last_ids[
           ChatPublisher.user_tracking_state_message_bus_channel(scope.user.id)
         ]
      last_ids[:user_tracking_state] = id
    end

    { message_bus_last_ids: last_ids }
  end

  private

  def chat_message_bus_last_ids
    @chat_message_bus_last_ids ||=
      begin
        message_bus_channels = [
          ChatPublisher::CHANNEL_METADATA_MESSAGE_BUS_CHANNEL,
          ChatPublisher::CHANNEL_EDITS_MESSAGE_BUS_CHANNEL,
          ChatPublisher::CHANNEL_STATUS_MESSAGE_BUS_CHANNEL,
          ChatPublisher::NEW_CHANNEL_MESSAGE_BUS_CHANNEL,
          ChatPublisher::CHANNEL_ARCHIVE_STATUS_MESSAGE_BUS_CHANNEL,
        ]

        if !scope.anonymous?
          message_bus_channels.push(
            ChatPublisher.user_tracking_state_message_bus_channel(scope.user.id),
          )
        end

        object[:public_channels].each do |channel|
          message_bus_channels.push(ChatPublisher.new_messages_message_bus_channel(channel.id))
          message_bus_channels.push(ChatPublisher.new_mentions_message_bus_channel(channel.id))
          message_bus_channels.push(ChatPublisher.kick_users_message_bus_channel(channel.id))
        end

        object[:direct_message_channels].each do |channel|
          message_bus_channels.push(ChatPublisher.new_messages_message_bus_channel(channel.id))
          message_bus_channels.push(ChatPublisher.new_mentions_message_bus_channel(channel.id))
        end

        MessageBus.last_ids(*message_bus_channels)
      end
  end
end
