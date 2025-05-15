# frozen_string_literal: true

Fabricator(:post_localization) do
  post
  locale { "ja" }
  raw { sequence(:localization_raw) { |n| "これはローカライズされた投稿です。#{n}" } }
  cooked { |attrs| "<p>#{attrs[:raw]}</p>" }
  post_version { |attrs| attrs[:post].version }
  localizer_user_id { Discourse.system_user.id }
end
