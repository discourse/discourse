Fabricator(:user_field) do
  name { sequence(:name) { |i| "field_#{i}" } }
  description "user field description"
  field_type 'text'
  editable true
  required true
end
