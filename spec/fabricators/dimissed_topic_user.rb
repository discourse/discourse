# frozen_string_literal: true

Fabricator(:dismissed_topic_user) do
  user
  topic
  created_at { Time.zone.now }
end
