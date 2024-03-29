# frozen_string_literal: true

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggers::PM_CREATED) do
  field :restricted_user, component: :user
  field :restricted_group, component: :group
  field :ignore_staff, component: :boolean
  field :ignore_automated, component: :boolean
  field :ignore_group_members, component: :boolean
  field :valid_trust_levels, component: :"trust-levels"
end
