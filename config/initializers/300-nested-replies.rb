# frozen_string_literal: true

Rails.application.config.to_prepare { require "nested_replies" }

DiscourseEvent.on(:topic_created) do |topic, _opts, _user|
  next unless SiteSetting.nested_replies_enabled
  next unless topic.regular?

  if SiteSetting.nested_replies_default || topic.category&.nested_replies_default
    NestedTopic.find_or_create_by!(topic: topic)
  end
end

DiscourseEvent.on(:like_created) do |post_action, _creator|
  next unless SiteSetting.nested_replies_enabled

  NestedReplies::HotScoreCalculator.recalculate_for_post(post_action.post_id)
end

DiscourseEvent.on(:like_destroyed) do |post_action, _destroyer|
  next unless SiteSetting.nested_replies_enabled

  NestedReplies::HotScoreCalculator.recalculate_for_post(post_action.post_id)
end
