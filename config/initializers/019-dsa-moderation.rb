# frozen_string_literal: true
DiscourseEvent.on(:model_trashed) { |target| DsaModeration.record_removal(target) }
DiscourseEvent.on(:post_destroyed) do |post, _options, _actor|
  DsaModeration.record_removal(post) if post.deleted_at.present?
end
DiscourseEvent.on(:topic_recovered) do |topic, _actor|
  DsaModeration.record_topic_restoration(topic)
end
DiscourseEvent.on(:topic_destroyed) { |topic, _actor| DsaModeration.record_topic_removal(topic) }
DiscourseEvent.on(:user_suspended) do |options|
  DsaModeration.record_account_restriction(
    user: options[:user],
    restriction: {
      "decision_account" => "DECISION_ACCOUNT_SUSPENDED",
    },
  )
end
DiscourseEvent.on(:user_silenced) do |options|
  DsaModeration.record_account_restriction(
    user: options[:user],
    restriction: {
      "decision_provision" => "DECISION_PROVISION_PARTIAL_SUSPENSION",
    },
  )
end
DiscourseEvent.on(:topic_status_updated) do |topic, status, enabled|
  DsaModeration.record_topic_status(topic: topic, status: status, enabled: enabled)
end
DiscourseEvent.on(:post_edited) do |post, _topic_changed, revisor|
  DsaModeration.record_edit(post: post, changes: revisor.post_changes.merge(revisor.topic_diff))
end
