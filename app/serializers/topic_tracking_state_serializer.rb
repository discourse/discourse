# frozen_string_literal: true

class TopicTrackingStateSerializer < ApplicationSerializer
  attributes :data, :meta

  def data
    object.each do |item|
      TopicTrackingStateItemSerializer.new(item, scope: scope, root: false).as_json
    end
  end

  def meta
    channels = [
      TopicTrackingState::PUBLISH_LATEST_MESSAGE_BUS_CHANNEL,
      TopicTrackingState::PUBLISH_RECOVER_MESSAGE_BUS_CHANNEL,
      TopicTrackingState::PUBLISH_DELETE_MESSAGE_BUS_CHANNEL,
      TopicTrackingState::PUBLISH_DESTROY_MESSAGE_BUS_CHANNEL,
    ]

    if !scope.anonymous?
      channels.push(
        TopicTrackingState::PUBLISH_NEW_MESSAGE_BUS_CHANNEL,
        TopicTrackingState::PUBLISH_UNREAD_MESSAGE_BUS_CHANNEL,
        TopicTrackingState.unread_channel_key(scope.user.id),
      )
    end

    MessageBus.last_ids(*channels)
  end
end
