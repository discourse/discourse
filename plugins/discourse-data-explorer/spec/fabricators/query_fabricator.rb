# frozen_string_literal: true

Fabricator(:query, from: DiscourseDataExplorer::Query) do
  name { sequence(:name) { |i| "cat#{i}" } }
  description { sequence(:desc) { |i| "description #{i}" } }
  sql { sequence(:sql) { |i| "SELECT * FROM users WHERE id > 0 LIMIT #{i}" } }
  user
end

Fabricator(:query_group, from: DiscourseDataExplorer::QueryGroup) do
  query
  group
end
