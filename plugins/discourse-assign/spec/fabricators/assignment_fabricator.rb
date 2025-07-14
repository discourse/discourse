# frozen_string_literal: true

Fabricator(:topic_assignment, class_name: :assignment) do
  topic
  target { |attrs| attrs[:topic] }
  target_type "Topic"
  assigned_by_user { Fabricate(:user) }
  assigned_to { Fabricate(:user) }
end

Fabricator(:post_assignment, class_name: :assignment) do
  transient :post
  topic { |attrs| attrs[:post]&.topic || Fabricate(:topic) }
  target { |attrs| attrs[:post] || Fabricate(:post, topic: attrs[:topic]) }
  target_type "Post"
  assigned_by_user { Fabricate(:user) }
  assigned_to { Fabricate(:user) }
end
