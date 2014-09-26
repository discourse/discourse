Fabricator(:user_field) do
  name { sequence(:name) {|i| "field_#{i}" } }
  field_type 'text'
  editable true
end
