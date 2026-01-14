# frozen_string_literal: true

Fabricator(:tag_localization) do
  tag
  locale "ja"
  name { sequence(:name) { |i| "猫タグ#{i + 1}" } }
  description "猫についてのタグです"
end
