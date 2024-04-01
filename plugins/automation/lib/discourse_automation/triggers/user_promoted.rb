# frozen_string_literal: true

DiscourseAutomation::Triggerable::USER_PROMOTED = "user_promoted"

DiscourseAutomation::Triggerable::USER_PROMOTED_TRUST_LEVEL_CHOICES = [
  { id: "TLALL", name: "discourse_automation.triggerables.user_promoted.trust_levels.ALL" },
  { id: "TL01", name: "discourse_automation.triggerables.user_promoted.trust_levels.TL01" },
  { id: "TL12", name: "discourse_automation.triggerables.user_promoted.trust_levels.TL12" },
  { id: "TL23", name: "discourse_automation.triggerables.user_promoted.trust_levels.TL23" },
  { id: "TL34", name: "discourse_automation.triggerables.user_promoted.trust_levels.TL34" },
]

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggerable::USER_PROMOTED) do
  field :restricted_group, component: :group
  field :trust_level_transition,
        component: :choices,
        extra: {
          content: DiscourseAutomation::Triggerable::USER_PROMOTED_TRUST_LEVEL_CHOICES,
        },
        required: true

  placeholder :trust_level_transition
end
