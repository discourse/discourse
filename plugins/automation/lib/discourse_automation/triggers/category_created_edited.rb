# frozen_string_literal: true

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggers::CATEGORY_CREATED_EDITED) do
  field :restricted_category, component: :category
end
