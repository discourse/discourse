# frozen_string_literal: true

DiscourseAutomation::Triggerable::USER_UPDATED = "user_updated"

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggerable::USER_UPDATED) do
  field :automation_name, component: :text, required: true
  field :custom_fields, component: :custom_fields, required: true
  field :user_profile, component: :user_profile, required: true
  field :first_post_only, component: :boolean
end
