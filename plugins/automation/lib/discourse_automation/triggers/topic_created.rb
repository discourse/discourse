# frozen_string_literal: true

DiscourseAutomation::Triggerable::TOPIC_CREATED = "topic_created"

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggerable::TOPIC_CREATED) do
  field :valid_trust_levels, component: :"trust-levels"
end
