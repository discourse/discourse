# frozen_string_literal: true

DiscourseAutomation::Scriptable::PIN_TOPIC = "pin_topic"

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scriptable::PIN_TOPIC) do
  field :pinnable_topic, component: :text, required: true
  field :pinned_until, component: :date_time
  field :pinned_globally, component: :boolean

  version 1

  triggerables [:point_in_time]

  script do |_context, fields|
    next unless topic_id = fields.dig("pinnable_topic", "value")
    next unless topic = Topic.find_by(id: topic_id)

    pinned_globally = fields.dig("pinned_globally", "value") || false
    pinned_until = fields.dig("pinned_until", "value") || nil

    topic.update_pinned(true, pinned_globally, pinned_until)
  end
end
