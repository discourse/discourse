# frozen_string_literal: true

class StructuredChannelSerializer < ApplicationSerializer
  attributes :public_channels, :direct_message_channels

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
end
