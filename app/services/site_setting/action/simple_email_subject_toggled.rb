# frozen_string_literal: true

class SiteSetting::Action::SimpleEmailSubjectToggled
  include Service::Base

  SIMPLE_EMAIL_SUBJECT = "%{site_name}: %{topic_title}"

  params { attribute :setting_enabled, :boolean }

  step :update_email_subject
  only_if(:has_setting_enabled) { step :copy_translation_overrides }
  step :request_refresh

  def has_setting_enabled(params:)
    params.setting_enabled
  end

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

  def copy_translation_overrides
    TranslationOverride
      .where(locale: SiteSetting.default_locale)
      .where.not("translation_key LIKE '%_improved'")
      .find_each do |override|
        improved_key = improved_variant_of(override.translation_key)
        next unless improved_key

        TranslationOverride.upsert!(SiteSetting.default_locale, improved_key, override.value)
      end
  end

  def improved_variant_of(key)
    return "#{key}_improved" if I18n.exists?("#{key}_improved")

    # pluralized keys store suffix on the parent: "foo.one" maps to "foo_improved.one"
    match = key.match(/\A(.+)\.(zero|one|two|few|many|other)\z/)
    return nil unless match

    pluralized = "#{match[1]}_improved.#{match[2]}"
    I18n.exists?(pluralized) ? pluralized : nil
  end

  def request_refresh
    Discourse.request_refresh!
  end
end
