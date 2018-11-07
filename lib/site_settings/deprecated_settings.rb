module SiteSettings; end

module SiteSettings::DeprecatedSettings
  DEPRECATED_SETTINGS = [
  ]

  def setup_deprecated_methods
    DEPRECATED_SETTINGS.each do |old_setting, new_setting, version|
      define_singleton_method old_setting do
        logger.warn("`SiteSetting.#{old_setting}` has been deprecated and will be removed in the #{version} Release. Please use `SiteSetting.#{new_setting}` instead")
        self.public_send new_setting
      end

      define_singleton_method "#{old_setting}?" do
        logger.warn("`SiteSetting.#{old_setting}?` has been deprecated and will be removed in the #{version} Release. Please use `SiteSetting.#{new_setting}?` instead")
        self.public_send "#{new_setting}?"
      end

      define_singleton_method "#{old_setting}=" do |val|
        logger.warn("`SiteSetting.#{old_setting}=` has been deprecated and will be removed in the #{version} Release. Please use `SiteSetting.#{new_setting}=` instead")
        self.public_send "#{new_setting}=", val
      end
    end
  end
end
