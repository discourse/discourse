# frozen_string_literal: true

Fabricator(:user_field_option) do
  user_field
  value { sequence(:name) { |i| "field_option_#{i}" } }
end
