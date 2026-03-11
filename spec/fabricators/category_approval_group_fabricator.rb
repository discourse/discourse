# frozen_string_literal: true

Fabricator(:category_approval_group) do
  category
  group
  approval_type { "topic" }
end
