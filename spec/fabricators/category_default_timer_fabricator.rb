# frozen_string_literal: true

Fabricator(:category_default_timer) do
  user { Discourse.system_user }
  category
  execute_at { 1.hour.from_now }
  status_type TopicTimer.types[:close]
end
