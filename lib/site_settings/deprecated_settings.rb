module SiteSettings; end

module SiteSettings::DeprecatedSettings
  SETTINGS = [
    ['logo_url', 'logo', false, '2.4'],
    ['logo_small_url', 'logo_small', false, '2.4'],
    ['digest_logo_url', 'digest_logo', false, '2.4'],
    ['mobile_logo_url', 'mobile_logo', false, '2.4'],
    ['large_icon_url', 'large_icon', false, '2.4'],
    ['favicon_url', 'favicon', false, '2.4'],
    ['apple_touch_icon_url', 'apple_touch_icon', false, '2.4'],
    ['default_opengraph_image_url', 'opengraph_image', false, '2.4'],
    ['twitter_summary_large_image_url', 'twitter_summary_large_image', false, '2.4'],
    ['push_notifications_icon_url', 'push_notifications_icon', false, '2.4']
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
