# frozen_string_literal: true

Fabricator(:user_field) do
  name { sequence(:name) { |i| "field_#{i}" } }
  description "user field description"
  field_type "text"
  editable true
  requirement "on_signup"
end

Fabricator(:user_field_dropdown, from: :user_field) do
  field_type "dropdown"
  after_create do |user_field|
    Fabricate(:user_field_option, user_field: user_field)
    Fabricate(:user_field_option, user_field: user_field)
    Fabricate(:user_field_option, user_field: user_field)
  end
end
