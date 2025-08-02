# frozen_string_literal: true

Fabricator(:user_badge) do
  user
  badge
  granted_at { Time.zone.now }
  granted_by(fabricator: :admin)
end
