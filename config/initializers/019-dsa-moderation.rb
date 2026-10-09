# frozen_string_literal: true

DiscourseEvent.on(:dsa_user_history_created) do |history, metadata = nil|
  DsaModeration.record_user_history(history, metadata)
end

DiscourseEvent.on(
  :dsa_reviewable_action_performed,
) do |reviewable, result, actor, action_name, args|
  DsaModeration.record_action(reviewable, result, actor, action_name, args)
end

DiscourseEvent.on(:dsa_post_destroyed) do |post, options, actor|
  DsaModeration.record_post_destroyed(post, options, actor)
end

DiscourseEvent.on(:dsa_post_hidden) do |post, metadata|
  DsaModeration.record_post_hidden(post, metadata)
end

DiscourseEvent.on(:dsa_chat_message_deleted) do |message, actor, metadata|
  DsaModeration.record_removal(message, actor, metadata)
end

DiscourseEvent.on(:dsa_post_voting_comment_deleted) do |comment, actor, metadata|
  DsaModeration.record_removal(comment, actor, metadata)
end

DiscourseEvent.on(:dsa_topic_status_updated) do |topic, status, enabled, metadata = nil|
  DsaModeration.record_topic_status(
    topic: topic,
    status: status,
    enabled: enabled,
    metadata: metadata,
  )
end

DiscourseEvent.on(:dsa_post_edited) do |post, _topic_changed, revisor|
  DsaModeration.record_edit(post: post, revisor: revisor)
end

DiscourseEvent.on(:dsa_posts_moved) { |options| DsaModeration.record_moved_posts(**options) }
