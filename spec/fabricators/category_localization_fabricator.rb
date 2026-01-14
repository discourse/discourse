# frozen_string_literal: true

Fabricator(:category_localization) do
  category
  locale "ja"
  name { sequence(:name) { |i| "ワク" * (i + 1) } }
  description "日本のディスカッション"
end
