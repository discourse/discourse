# frozen_string_literal: true

DiscourseAutomation::Triggerable::PM_CREATED = "pm_created"

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggerable::PM_CREATED) do
  field :restricted_user, component: :user
  field :ignore_staff, component: :boolean
  field :valid_trust_levels, component: :"trust-levels"
end
