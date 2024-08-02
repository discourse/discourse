# frozen_string_literal: true

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED) do
  field :watching_categories, component: :categories
  field :watching_tags, component: :tags
end
