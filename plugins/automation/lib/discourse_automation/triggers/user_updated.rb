# frozen_string_literal: true

class DiscourseAutomation::Triggerable
  USER_UPDATED = "user_updated"
end

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggerable::USER_UPDATED) do
  field :automation_name, component: :text, required: true
  field :custom_fields, component: :custom_fields
  field :user_profile, component: :user_profile
  field :first_post_only, component: :boolean

  validate do
    has_triggers = has_trigger_field?(:custom_fields) && has_trigger_field?(:user_profile)
    custom_fields = trigger_field(:custom_fields)["value"]
    user_profile = trigger_field(:user_profile)["value"]

    if has_triggers && custom_fields.blank? && user_profile.blank?
      errors.add(
        :base,
        I18n.t("discourse_automation.triggerables.errors.custom_fields_or_user_profile_required"),
      )
      false
    else
      true
    end
  end
end
