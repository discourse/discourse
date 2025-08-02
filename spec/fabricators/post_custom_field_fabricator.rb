# frozen_string_literal: true

Fabricator(:post_custom_field) do
  post
  name { sequence(:key) { |i| "key#{i}" } }
  value "test value"
end
