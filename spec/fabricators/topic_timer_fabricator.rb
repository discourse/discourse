# frozen_string_literal: true

Fabricator(:topic_timer) do
  user
  topic
  execute_at { 1.hour.from_now }
  status_type TopicTimer.types[:close]
end

Fabricator(:topic_timer_close_based_on_last_post, from: :topic_timer) do
  based_on_last_post { true }
  duration_minutes { 2.days.to_i / 60 }
end
