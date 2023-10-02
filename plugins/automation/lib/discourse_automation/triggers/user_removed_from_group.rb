# frozen_string_literal: true

DiscourseAutomation::Triggerable::USER_REMOVED_FROM_GROUP = "user_removed_from_group"

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggerable::USER_REMOVED_FROM_GROUP) do
  field :left_group, component: :group, required: true

  placeholder :group_name
end
