# frozen_string_literal: true

Rails.application.config.to_prepare do
  require "nested_replies"

  Category.register_custom_field_type(NestedReplies::CONVERSION_COMPLETED_CUSTOM_FIELD, :boolean)
end

DiscourseEvent.on(:site_setting_changed) do |name, old_value, new_value|
  enabling_feature = name == :nested_replies_enabled && !old_value && new_value
  enabling_default = name == :nested_replies_default && !old_value && new_value
  next unless enabling_feature || enabling_default

  # Make every older completion marker untrustworthy immediately. The job can
  # then invalidate and rebuild individual topics in bounded batches.
  cutoff = DB.query_single("SELECT EXTRACT(EPOCH FROM clock_timestamp())").first.to_f
  SiteSetting.nested_replies_stats_valid_after = [
    SiteSetting.nested_replies_stats_valid_after.to_f,
    cutoff,
  ].max
  Jobs.enqueue(:invalidate_nested_reply_stats)
rescue => error
  Discourse.warn_exception(error, message: "Failed to queue nested reply stat invalidation")
end

DiscourseEvent.on(:topic_created) do |topic, _opts, _user|
  next unless SiteSetting.nested_replies_enabled
  next unless topic.regular?

  if SiteSetting.nested_replies_default || topic.category&.nested_replies_default
    NestedTopic.find_or_create_by!(topic: topic)
  end
end

DiscourseEvent.on(:like_created) do |post_action, _creator|
  next unless SiteSetting.nested_replies_enabled

  NestedReplies::RecalculationQueue.enqueue_hot_post_if_nested(post_action.post_id)
end

DiscourseEvent.on(:like_destroyed) do |post_action, _destroyer|
  next unless SiteSetting.nested_replies_enabled

  NestedReplies::RecalculationQueue.enqueue_hot_post_if_nested(post_action.post_id)
end

%i[post_created post_recovered].each do |event|
  DiscourseEvent.on(event) do |post, *_args|
    next unless SiteSetting.nested_replies_enabled

    NestedReplies::RecalculationQueue.enqueue_hot_post_if_nested(post.id)
  end
end

DiscourseEvent.on(:post_destroyed) do |post, *_args|
  next unless SiteSetting.nested_replies_enabled

  DB.after_commit do
    NestedReplies::RecalculationQueue.enqueue_topic_rebuilds(
      [post.topic_id],
      structural: false,
      hot: true,
    )
  end
end
