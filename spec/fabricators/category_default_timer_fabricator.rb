# frozen_string_literal: true

Fabricator(:category_default_timer) do
  user { Discourse.system_user }
  timerable_id { |attrs| attrs[:category]&.id || attrs[:category_id] }
  execute_at { 1.hour.from_now }
  status_type CategoryDefaultTimer.types[:close]
end
