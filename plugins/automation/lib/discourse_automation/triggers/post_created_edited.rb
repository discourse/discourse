# frozen_string_literal: true

DiscourseAutomation::Triggerable::POST_CREATED_EDITED = "post_created_edited"

ACTION_TYPE_CHOICES = [
  { id: "created", name: "discourse_automation.triggerables.post_created_edited.created" },
  { id: "edited", name: "discourse_automation.triggerables.post_created_edited.edited" },
]

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggerable::POST_CREATED_EDITED) do
  field :action_type, component: :choices, extra: { content: ACTION_TYPE_CHOICES }
  field :restricted_category, component: :category
  field :restricted_group, component: :group
  field :ignore_automated, component: :boolean
  field :ignore_group_members, component: :boolean
  field :valid_trust_levels, component: :"trust-levels"
end
