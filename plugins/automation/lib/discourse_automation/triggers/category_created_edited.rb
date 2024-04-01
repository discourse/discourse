# frozen_string_literal: true

DiscourseAutomation::Triggerable::CATEGORY_CREATED_EDITED = "category_created_edited"

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggerable::CATEGORY_CREATED_EDITED) do
  field :restricted_category, component: :category
end
