# frozen_string_literal: true

Fabricator(:group_request) do
  user
  group
  reason { sequence(:reason) { |n| "group request #{n}" } }
end
