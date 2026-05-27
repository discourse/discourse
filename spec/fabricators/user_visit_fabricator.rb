# frozen_string_literal: true

Fabricator(:user_visit) do
  user
  visited_at Date.today
  mobile false
end
