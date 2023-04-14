# frozen_string_literal: true

Fabricator(:category_group) do
  category
  group
  permission_type 1
end
