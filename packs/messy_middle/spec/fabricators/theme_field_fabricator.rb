# frozen_string_literal: true

Fabricator(:theme_field) do
  theme
  target_id { 0 }
  name { sequence(:name) { |i| "scss_#{i + 1}" } }
  value { ".test {color: blue;}" }
  error { nil }
end
