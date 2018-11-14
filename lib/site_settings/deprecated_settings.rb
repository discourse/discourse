module SiteSettings; end

module SiteSettings::DeprecatedSettings
  DEPRECATED_SETTINGS = [
    %w{logo_url logo 2.4},
    %w{logo_small_url logo_small 2.4},
    %w{digest_logo_url digest_logo 2.4},
    %w{mobile_logo_url mobile_logo 2.4},
    %w{large_icon_url large_icon 2.4},
    %w{favicon_url favicon 2.4},
    %w{apple_touch_icon_url apple_touch_icon 2.4},
    %w{default_opengraph_image_url opengraph_image 2.4},
    %w{twitter_summary_large_image_url twitter_summary_large_image 2.4},
    %w{push_notifications_icon_url push_notifications_icon 2.4}
  ]

  def setup_deprecated_methods
    DEPRECATED_SETTINGS.each do |old_setting, new_setting, version|
      define_singleton_method old_setting do |warn: true|
        if warn
          logger.warn(
            "`SiteSetting.#{old_setting}` has been deprecated and will be " +
            "removed in the #{version} Release. Please use " +
            "`SiteSetting.#{new_setting}` instead"
          )
        end

        self.public_send new_setting
      end

      define_singleton_method "#{old_setting}?" do |warn: true|
        if warn
          logger.warn(
            "`SiteSetting.#{old_setting}?` has been deprecated and will be " +
            "removed in the #{version} Release. Please use " +
            "`SiteSetting.#{new_setting}?` instead"
          )
        end

        self.public_send "#{new_setting}?"
      end

      define_singleton_method "#{old_setting}=" do |val, warn: true|
        if warn
          logger.warn(
            "`SiteSetting.#{old_setting}=` has been deprecated and will be " +
            "removed in the #{version} Release. Please use " +
            "`SiteSetting.#{new_setting}=` instead"
          )
        end

        self.public_send "#{new_setting}=", val
      end
    end
  end
end
