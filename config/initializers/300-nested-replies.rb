# frozen_string_literal: true

Rails.application.config.to_prepare { require "nested_replies" }

DiscourseEvent.on(:topic_created) do |topic, _opts, _user|
  next unless SiteSetting.nested_replies_enabled

  if SiteSetting.nested_replies_default || topic.category&.nested_replies_default
    NestedTopic.create!(topic: topic)
  end
end
