# frozen_string_literal: true

class StructuredChannelSerializer < ApplicationSerializer
  attributes :public_channels, :direct_message_channels, :message_bus_last_ids

  def public_channels
    object[:public_channels].map do |channel|
      ChatChannelSerializer.new(
        channel,
        root: nil,
        scope: scope,
        membership: channel_membership(channel.id),
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
      )
    end
  end

  def channel_membership(channel_id)
    return if scope.anonymous?
    object[:memberships].find { |membership| membership.chat_channel_id == channel_id }
  end

  def message_bus_last_ids
    last_ids = {
      channel_metadata: MessageBus.last_id("/chat/channel-metadata"),
      channel_edits: MessageBus.last_id("/chat/channel-edits"),
      channel_status: MessageBus.last_id("/chat/channel-status"),
      new_channel: MessageBus.last_id("/chat/new-channel"),
    }
    if !scope.anonymous?
      last_ids[:user_tracking_state] = MessageBus.last_id(
        "/chat/user-tracking-state/#{scope.user.id}",
      )
    end
    last_ids
  end
end
