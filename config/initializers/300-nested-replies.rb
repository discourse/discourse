# frozen_string_literal: true

Rails.application.config.to_prepare do
  require "nested_replies"

  Category.register_custom_field_type(NestedReplies::CONVERSION_COMPLETED_CUSTOM_FIELD, :boolean)
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

  NestedReplies::HotScoreCalculator.recalculate_for_post_if_nested(post_action.post_id)
end

DiscourseEvent.on(:like_destroyed) do |post_action, _destroyer|
  next unless SiteSetting.nested_replies_enabled

  NestedReplies::HotScoreCalculator.recalculate_for_post_if_nested(post_action.post_id)
end

%i[post_created post_recovered].each do |event|
  DiscourseEvent.on(event) do |post, *_args|
    next unless SiteSetting.nested_replies_enabled

    NestedReplies::HotScoreCalculator.recalculate_for_post_if_nested(post.id)
  end
end

DiscourseEvent.on(:post_destroyed) do |post, *_args|
  next unless SiteSetting.nested_replies_enabled

  NestedReplies::HotScoreCalculator.recalculate_after_post_destroyed(post)
end
