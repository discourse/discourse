# frozen_string_literal: true

# Registers TopicView.on_preload hooks for nested replies:
# 1. Batch-load direct reply counts for the flat view (powers "View as nested" toggle)
# 2. Batch precompute reactions to avoid N+1 from discourse-reactions

TopicView.on_preload do |topic_view|
  next unless SiteSetting.nested_replies_enabled
  next if topic_view.nested_replies_skip_preload

  post_numbers = topic_view.posts.map(&:post_number)
  next if post_numbers.empty?

  visible_types = [Post.types[:regular], Post.types[:moderator_action]]
  visible_types << Post.types[:whisper] if topic_view.guardian.user&.whisperer?

  counts =
    Post
      .where(topic_id: topic_view.topic.id, deleted_at: nil)
      .where(reply_to_post_number: post_numbers)
      .where(post_type: visible_types)
      .group(:reply_to_post_number)
      .count

  topic_view.nested_replies_direct_reply_counts = counts
end
