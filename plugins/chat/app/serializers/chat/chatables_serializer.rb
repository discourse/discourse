# frozen_string_literal: true

module Chat
  class ChatablesSerializer < ::ApplicationSerializer
    attributes :users
    attributes :direct_message_channels
    attributes :category_channels

    def users
      (object.users || [])
        .map do |user|
          {
            identifier: "u-#{user.id}",
            model: ::Chat::ChatableUserSerializer.new(user, scope: scope, root: false),
            type: "user",
          }
        end
        .as_json
    end

    def direct_message_channels
      (object.direct_message_channels || [])
        .map do |channel|
          {
            identifier: "c-#{channel.id}",
            type: "channel",
            model:
              ::Chat::ChannelSerializer.new(
                channel,
                scope: scope,
                root: false,
                membership: channel_membership(channel.id),
              ),
          }
        end
        .as_json
    end

    def category_channels
      (object.category_channels || [])
        .map do |channel|
          {
            identifier: "c-#{channel.id}",
            type: "channel",
            model:
              ::Chat::ChannelSerializer.new(
                channel,
                scope: scope,
                root: false,
                membership: channel_membership(channel.id),
              ),
          }
        end
        .as_json
    end

    private

    def channel_membership(channel_id)
      object.memberships.find { |membership| membership.chat_channel_id == channel_id }
    end
  end
end
