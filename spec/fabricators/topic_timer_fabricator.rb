# frozen_string_literal: true

Fabricator(:topic_timer) do
  user
  # TODO: Replace the next line with a single `topic` when `topic_id` column is dropped
  timerable_id { |attrs| attrs[:topic]&.id || attrs[:topic_id] }
  execute_at { 1.hour.from_now }
  status_type TopicTimer.types[:close]
end
