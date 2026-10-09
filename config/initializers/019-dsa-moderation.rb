# frozen_string_literal: true

DiscourseEvent.on(:model_trashed) { |target| DsaModeration.record_removal(target) }

DiscourseEvent.on(:user_history_created) { |history| DsaModeration.record_user_history(history) }

DiscourseEvent.on(:reviewable_history_created) do |history|
  DsaModeration.record_reviewable_history(history)
end

DiscourseEvent.on(:posts_hidden) do |post_ids, **options|
  DsaModeration.record_hidden_posts(post_ids, **options)
end

DiscourseEvent.on(:topic_status_updated) do |topic, status, enabled|
  DsaModeration.record_topic_status(topic: topic, status: status, enabled: enabled)
end

DiscourseEvent.on(:post_edited) do |post, _topic_changed, revisor|
  DsaModeration.record_edit(post: post, revisor: revisor)
end

DiscourseEvent.on(:posts_moved) { |options| DsaModeration.record_moved_posts(**options) }
