# frozen_string_literal: true

DiscourseAutomation::Triggerable::USER_ADDED_TO_GROUP = "user_added_to_group"

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggerable::USER_ADDED_TO_GROUP) do
  field :joined_group, component: :group, required: true

  placeholder :group_name
end
