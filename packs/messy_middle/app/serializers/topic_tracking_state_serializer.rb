# frozen_string_literal: true

class TopicTrackingStateSerializer < ApplicationSerializer
  attributes :data, :meta

  def data
    serializer = TopicTrackingStateItemSerializer.new(nil, scope: scope, root: false)
    # note we may have 1000 rows, avoiding serializer instansitation saves significant time
    # for 1000 rows this takes it down from 10ms to 3ms on a reasonably fast machine
    object.map do |item|
      serializer.object = item
      serializer.as_json
    end
  end

  def meta
    MessageBus.last_ids(
      TopicTrackingState::LATEST_MESSAGE_BUS_CHANNEL,
      TopicTrackingState::RECOVER_MESSAGE_BUS_CHANNEL,
      TopicTrackingState::DELETE_MESSAGE_BUS_CHANNEL,
      TopicTrackingState::DESTROY_MESSAGE_BUS_CHANNEL,
      TopicTrackingState::NEW_MESSAGE_BUS_CHANNEL,
      TopicTrackingState::UNREAD_MESSAGE_BUS_CHANNEL,
      TopicTrackingState.unread_channel_key(scope.user.id),
    )
  end
end
