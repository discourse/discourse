# frozen_string_literal: true

Fabricator(:moved_post) do
  created_new_topic false
  new_topic { Fabricate(:topic) }
  new_post { Fabricate(:post) }
  old_topic { Fabricate(:topic) }
  old_post { Fabricate(:post) }

  after_build do |moved_post, transients|
    moved_post.new_topic_title = moved_post.new_topic.title
    moved_post.new_post_number = moved_post.new_post.post_number
    moved_post.old_post_number = moved_post.old_post.post_number
  end
end
