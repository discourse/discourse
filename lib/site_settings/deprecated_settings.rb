# frozen_string_literal: true

module SiteSettings
end

module SiteSettings::DeprecatedSettings
  SETTINGS = [
    # [<old setting>, <new_setting>, <override>, <version to drop>]
    ["min_first_post_typing_time", "fast_typing_threshold", false, "3.4"],
    ["twitter_summary_large_image", "x_summary_large_image", false, "3.4"],
    ["external_system_avatars_enabled", "external_system_avatars_url", false, "3.5"],
  ]

  def setup_deprecated_methods
    SETTINGS.each { |s| setup_deprecated_method(*s) }
  end

  def setup_deprecated_method(old_setting, new_setting, override, version)
    SiteSetting.singleton_class.alias_method(:"_#{old_setting}", :"#{old_setting}") if !override

    define_singleton_method old_setting do |scoped_to = nil, warn: true|
      if warn
        Discourse.deprecate(
          "`SiteSetting.#{old_setting}` has been deprecated. Please use `SiteSetting.#{new_setting}` instead.",
          drop_from: version,
        )
      end

      self.public_send(override ? new_setting : "_#{old_setting}", scoped_to)
    end

    SiteSetting.singleton_class.alias_method(:"_#{old_setting}?", :"#{old_setting}?") if !override

    define_singleton_method "#{old_setting}?" do |scoped_to = nil, warn: true|
      if warn
        Discourse.deprecate(
          "`SiteSetting.#{old_setting}?` has been deprecated. Please use `SiteSetting.#{new_setting}?` instead.",
          drop_from: version,
        )
      end

      self.public_send("#{override ? new_setting : "_" + old_setting}?", scoped_to)
    end

    SiteSetting.singleton_class.alias_method(:"_#{old_setting}=", :"#{old_setting}=") if !override

    define_singleton_method "#{old_setting}=" do |val, warn: true|
      if warn
        Discourse.deprecate(
          "`SiteSetting.#{old_setting}=` has been deprecated. Please use `SiteSetting.#{new_setting}=` instead.",
          drop_from: version,
        )
      end

      self.public_send("#{override ? new_setting : "_" + old_setting}=", val)
    end
  end
end
