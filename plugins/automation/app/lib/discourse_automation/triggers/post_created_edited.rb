# frozen_string_literal: true

DiscourseAutomation::Triggerable::POST_CREATED_EDITED = "post_created_edited"

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggerable::POST_CREATED_EDITED) do
  field :restricted_category, component: :category
  field :valid_trust_levels, component: :"trust-levels"
end
