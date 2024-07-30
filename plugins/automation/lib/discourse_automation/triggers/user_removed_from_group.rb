# frozen_string_literal: true

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggers::USER_REMOVED_FROM_GROUP) do
  field :left_group, component: :group, required: true

  placeholder :group_name
end
