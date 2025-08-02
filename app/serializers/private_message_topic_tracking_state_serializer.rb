# frozen_string_literal: true

class PrivateMessageTopicTrackingStateSerializer < ApplicationSerializer
  attributes :topic_id,
             :highest_post_number,
             :last_read_post_number,
             :notification_level,
             :group_ids
end
