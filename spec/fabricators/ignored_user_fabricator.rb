# frozen_string_literal: true

Fabricator(:ignored_user) do
  user
  expiring_at 4.months.from_now
end
