# frozen_string_literal: true

DiscourseAutomation::Triggerable::AFTER_POST_COOK = "after_post_cook"

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggerable::AFTER_POST_COOK) do
  field :restricted_category, component: :category
  field :restricted_tags, component: :tags
  field :valid_trust_levels, component: :"trust-levels"
end
