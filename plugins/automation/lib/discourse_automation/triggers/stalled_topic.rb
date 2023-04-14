# frozen_string_literal: true

DiscourseAutomation::Triggerable::STALLED_TOPIC = "stalled_topic"

key = "discourse_automation.triggerables.stalled_topic.durations"
ids = %w[PT1H P1D P1W P2W P1M P3M P6M P1Y]
duration_choices = ids.map { |id| { id: id, name: "#{key}.#{id}" } }

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggerable::STALLED_TOPIC) do
  field :categories, component: :categories
  field :tags, component: :tags
  field :stalled_after, component: :choices, extra: { content: duration_choices }, required: true

  placeholder :topic_url
end
