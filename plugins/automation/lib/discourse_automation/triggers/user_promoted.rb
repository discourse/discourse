# frozen_string_literal: true

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggers::USER_PROMOTED) do
  field :restricted_group, component: :group
  field :trust_level_transition,
        component: :choices,
        extra: {
          content: DiscourseAutomation::USER_PROMOTED_TRUST_LEVEL_CHOICES,
        },
        required: true

  placeholder :trust_level_transition
end
