# frozen_string_literal: true

DiscourseEvent.on(:user_history_created) do |history, metadata = {}|
  DsaModeration.record_user_history(history, metadata)
end

DiscourseEvent.on(:reviewable_action_performed) do |reviewable, result, actor, action_name, args|
  DsaModeration.record_action(reviewable, result, actor, action_name, args)
end

DiscourseEvent.on(:post_destroyed) do |post, options, actor|
  DsaModeration.record_post_destroyed(post, options, actor)
end

DiscourseEvent.on(:post_hidden) do |post, metadata|
  DsaModeration.record_post_hidden(post, metadata)
end

DiscourseEvent.on(:chat_message_deleted) do |message, actor, metadata|
  DsaModeration.record_removal(message, actor, metadata)
end

DiscourseEvent.on(:post_voting_comment_deleted) do |comment, actor, metadata|
  DsaModeration.record_removal(comment, actor, metadata)
end

DiscourseEvent.on(:topic_status_updated) do |topic, status, enabled, metadata = {}|
  DsaModeration.record_topic_status(
    topic: topic,
    status: status,
    enabled: enabled,
    metadata: metadata,
  )
end

DiscourseEvent.on(:post_edited) do |post, _topic_changed, revisor|
  DsaModeration.record_edit(post: post, revisor: revisor)
end

DiscourseEvent.on(:posts_moved) { |options| DsaModeration.record_moved_posts(**options) }
