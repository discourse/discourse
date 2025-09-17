# frozen_string_literal: true

Fabricator(:topic_timer) do
  user
  topic
  execute_at { 1.hour.from_now }
  status_type TopicTimer.types[:close]
end
