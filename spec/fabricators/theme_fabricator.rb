Fabricator(:theme) do
  name { sequence(:name) { |i| "Cool theme #{i + 1}" } }
  user
end
