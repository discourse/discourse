# frozen_string_literal: true

Fabricator(:topic_view_stat) do
  topic { Fabricate(:topic) }
  viewed_at { Time.zone.now }
  anonymous_views { 1 }
  logged_in_views { 1 }
end
