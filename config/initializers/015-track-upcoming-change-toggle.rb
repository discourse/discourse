# frozen_string_literal: true
#
# Similar to 014-track-setting-changes.rb, we can react to upcoming changes
# being enabled/or disabled here for more complicated scenarios, where
# we are not just changing UI or behaviour when the state of the underlying
# setting is changed.
#
# We need to do this separately from 014-track-setting-changes.rb because
# we don't actually change the underlying setting value in the database
# when an upcoming change is automatically promoted. See UpcomingChanges::NotifyPromotions
# for further context.
#
# We do also send these events when admins manually opt-in or opt-out of an upcoming change
# via the UI and the UpcomingChanges::Toggle service.

DiscourseEvent.on(:upcoming_change_enabled) do |setting_name|
  # Respond to event here, e.g. if setting_name == :enable_form_templates do X.
  if setting_name == "simple_email_subject"
    SiteSetting.set_and_log(:email_subject, "%{site_name}: %{topic_title}")
    Discourse.request_refresh!

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
end

DiscourseEvent.on(:upcoming_change_disabled) do |setting_name|
  # Respond to event here, e.g. if setting_name == :enable_form_templates do X.
  if setting_name == "simple_email_subject"
    SiteSetting.set_and_log(:email_subject, SiteSetting.defaults.get(:email_subject))
    Discourse.request_refresh!

    TranslationOverride
      .where(locale: SiteSetting.default_locale)
      .each do |override|
        if override.translation_key.end_with?("_improved")
          TranslationOverride.revert!(SiteSetting.default_locale, [override.translation_key])
        end
      end
  end
end
