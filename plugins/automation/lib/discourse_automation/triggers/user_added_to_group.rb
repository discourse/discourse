# frozen_string_literal: true

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggers::USER_ADDED_TO_GROUP) do
  field :joined_group, component: :group, required: true

  placeholder :group_name
end
