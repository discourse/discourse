# frozen_string_literal: true

class TopicTrackingStateSerializer < ApplicationSerializer
  attributes :data, :meta

  def data
    object.map do |item|
      TopicTrackingStateItemSerializer.new(item, scope: scope, root: false).as_json
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
