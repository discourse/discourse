# frozen_string_literal: true

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggers::USER_BADGE_GRANTED) do
  field :badge,
        component: :choices,
        extra: {
          content: Badge.all.map { |b| { id: b.id, translated_name: b.name } },
        },
        required: true
  field :only_first_grant, component: :boolean
  placeholder :badge_name
  placeholder :grant_count
end
