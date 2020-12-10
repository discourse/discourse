# frozen_string_literal: true

Fabricator(:allowed_pm_user) do
  user
  starts_at { Time.current }
  ends_at { Time.current + 1.hour }
end
