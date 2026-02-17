# frozen_string_literal: true

module Chat
  class ChatablesSerializer < ::ApplicationSerializer
    attributes :users
    attributes :groups
    attributes :direct_message_channels
    attributes :category_channels

    def users
      (object.users || [])
        .map do |user|
          {
            identifier: "u-#{user.id}",
            model:
              ::Chat::ChatableUserSerializer.new(user, scope:, root: false, include_status: true),
            type: "user",
            match_quality: user.match_quality,
          }
        end
        .as_json
    end

    def groups
      (object.groups || [])
        .map do |group|
          {
            identifier: "g-#{group.id}",
            model: ::Chat::ChatableGroupSerializer.new(group, scope:, root: false),
            type: "group",
            match_quality: group.match_quality,
          }
        end
        .as_json
    end

    def direct_message_channels
      (object.direct_message_channels || [])
        .map do |channel|
          membership = channel_membership(channel.id)
          {
            identifier: "c-#{channel.id}",
            type: "channel",
            model: ::Chat::ChannelSerializer.new(channel, scope:, root: false, membership:),
            match_quality: channel.match_quality,
          }
        end
        .as_json
    end

    def category_channels
      (object.category_channels || [])
        .map do |channel|
          membership = channel_membership(channel.id)
          {
            identifier: "c-#{channel.id}",
            type: "channel",
            model: ::Chat::ChannelSerializer.new(channel, scope:, root: false, membership:),
            match_quality: channel.match_quality,
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
