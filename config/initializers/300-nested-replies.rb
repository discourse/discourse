# frozen_string_literal: true

Rails.application.config.to_prepare { require "nested_replies" }

DiscourseEvent.on(:topic_created) do |topic, _opts, _user|
  next unless SiteSetting.nested_replies_enabled

  if SiteSetting.nested_replies_default || topic.category&.nested_replies_default
    NestedTopic.find_or_create_by!(topic: topic)
  end
end

DiscourseEvent.on(:site_setting_changed) do |name, _old_value, new_value|
  if name == :nested_replies_enabled && new_value == true
    Jobs.enqueue(:backfill_nested_reply_stats, from_topic_id: 0)
  end
end
