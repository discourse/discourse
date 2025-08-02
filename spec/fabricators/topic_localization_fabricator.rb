# frozen_string_literal: true

Fabricator(:topic_localization) do
  topic
  locale { "ja" }
  title { sequence(:topic_localization_title) { |n| "これはローカライズされたトピックです。#{n}" } }
  fancy_title { |attrs| "a fancy #{attrs[:title]}" }
  localizer_user_id { Discourse.system_user.id }
end
