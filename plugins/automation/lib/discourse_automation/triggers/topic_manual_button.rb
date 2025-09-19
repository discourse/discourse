# frozen_string_literal: true

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggers::TOPIC_MANUAL_BUTTON) do
  field :categories, component: :categories
  field :allowed_groups, component: :groups

  enable_manual_trigger
end
