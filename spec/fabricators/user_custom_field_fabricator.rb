# frozen_string_literal: true

Fabricator(:user_custom_field) do
  user
  name { Fabricate(:user_field).id }
  value { sequence(:value) { |n| "value#{n}" } }
end
