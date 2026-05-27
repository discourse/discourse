# frozen_string_literal: true

Fabricator(:topic_link) do
  post
  transient :link_topic
  transient :link_post
  topic_id { |attrs| attrs[:post].topic_id }
  user_id { |attrs| attrs[:post].user_id }
  url { |attrs| attrs[:link_topic]&.url || "https://example.com/page" }
  domain "example.com"
  internal { |attrs| attrs[:link_topic].present? || attrs[:link_post].present? }
  link_topic_id { |attrs| attrs[:link_topic]&.id || attrs[:link_post]&.topic_id }
  link_post_id { |attrs| attrs[:link_post]&.id }
end
