class TopicTrackingStateSerializer < ApplicationSerializer
  attributes :topic_id,
             :highest_post_number,
             :last_read_post_number,
             :created_at,
             :category_id,
             :notification_level
end
