# frozen_string_literal: true

module SiteSettings; end

module SiteSettings::DeprecatedSettings
  SETTINGS = [
    ['logo_url', 'logo', false, '2.3'],
    ['logo_small_url', 'logo_small', false, '2.3'],
    ['digest_logo_url', 'digest_logo', false, '2.3'],
    ['mobile_logo_url', 'mobile_logo', false, '2.3'],
    ['large_icon_url', 'large_icon', false, '2.3'],
    ['favicon_url', 'favicon', false, '2.3'],
    ['apple_touch_icon_url', 'apple_touch_icon', false, '2.3'],
    ['default_opengraph_image_url', 'opengraph_image', false, '2.3'],
    ['twitter_summary_large_image_url', 'twitter_summary_large_image', false, '2.3'],
    ['push_notifications_icon_url', 'push_notifications_icon', false, '2.3'],
    ['show_email_on_profile', 'moderators_view_emails', true, '2.4'],
    ['allow_moderators_to_create_categories', 'moderators_create_categories', true, '2.4'],
    ['disable_edit_notifications', 'disable_system_edit_notifications', true, '2.4']
  ]

  def setup_deprecated_methods
    SETTINGS.each do |old_setting, new_setting, override, version|
      unless override
        SiteSetting.singleton_class.public_send(
          :alias_method, :"_#{old_setting}", :"#{old_setting}"
        )
      end

      define_singleton_method old_setting do |warn: true|
        if warn
          logger.warn(
            "`SiteSetting.#{old_setting}` has been deprecated and will be " +
            "removed in the #{version} Release. Please use " +
            "`SiteSetting.#{new_setting}` instead"
          )
        end

        self.public_send(override ? new_setting : "_#{old_setting}")
      end

      unless override
        SiteSetting.singleton_class.public_send(
          :alias_method, :"_#{old_setting}?", :"#{old_setting}?"
        )
      end

      define_singleton_method "#{old_setting}?" do |warn: true|
        if warn
          logger.warn(
            "`SiteSetting.#{old_setting}?` has been deprecated and will be " +
            "removed in the #{version} Release. Please use " +
            "`SiteSetting.#{new_setting}?` instead"
          )
        end

        self.public_send("#{override ? new_setting : "_" + old_setting}?")
      end

      unless override
        SiteSetting.singleton_class.public_send(
          :alias_method, :"_#{old_setting}=", :"#{old_setting}="
        )
      end

      define_singleton_method "#{old_setting}=" do |val, warn: true|
        if warn
          logger.warn(
            "`SiteSetting.#{old_setting}=` has been deprecated and will be " +
            "removed in the #{version} Release. Please use " +
            "`SiteSetting.#{new_setting}=` instead"
          )
        end

        self.public_send("#{override ? new_setting : "_" + old_setting}=", val)
      end
    end
  end
end
