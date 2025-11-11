# frozen_string_literal: true

Fabricator(:tag_localization) do
  tag
  locale "ja"
  name { sequence(:name) { |i| "タグ#{i + 1}" } }
  description "タグの説明"
end
