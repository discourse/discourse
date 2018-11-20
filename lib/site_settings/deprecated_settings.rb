module SiteSettings; end

module SiteSettings::DeprecatedSettings
  DEPRECATED_SETTINGS = [
    %w[use_https force_https 1.7],
    %w[min_private_message_post_length min_personal_message_post_length 2.0],
    %w[min_private_message_title_length min_personal_message_title_length 2.0],
    %w[enable_private_messages enable_personal_messages 2.0],
    %w[enable_private_email_messages enable_personal_email_messages 2.0],
    %w[private_email_time_window_seconds personal_email_time_window_seconds 2.0],
    %w[max_private_messages_per_day max_personal_messages_per_day 2.0],
    %w[default_email_private_messages default_email_personal_messages 2.0]
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
