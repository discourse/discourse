# frozen_string_literal: true

class SiteSetting::Action::SimpleEmailSubjectToggled
  include Service::Base

  SIMPLE_EMAIL_SUBJECT = "%{site_name}: %{topic_title}"

  params { attribute :setting_enabled, :boolean }

  step :update_email_subject
  step :copy_translation_overrides
  step :request_refresh

  private

  def update_email_subject(params:)
    if params.setting_enabled
      return if SiteSetting.email_subject != SiteSetting.defaults.get(:email_subject)
      SiteSetting.set_and_log(:email_subject, SIMPLE_EMAIL_SUBJECT)
    else
      return if SiteSetting.email_subject != SIMPLE_EMAIL_SUBJECT
      SiteSetting.set_and_log(:email_subject, SiteSetting.defaults.get(:email_subject))
    end
  end

  def copy_translation_overrides(params:)
    return unless params.setting_enabled

    TranslationOverride
      .where(locale: SiteSetting.default_locale)
      .each do |override|
        next if override.translation_key.end_with?("_improved")

        if I18n.exists?("#{override.translation_key}_improved")
          TranslationOverride.upsert!(
            SiteSetting.default_locale,
            "#{override.translation_key}_improved",
            override.value,
          )
        end
      end
  end

  def request_refresh
    Discourse.request_refresh!
  end
end
