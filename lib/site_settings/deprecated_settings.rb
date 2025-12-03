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

  OVERRIDE_TL_GROUP_SETTINGS = %w[]

  def group_to_tl(old_setting, new_setting)
    tl_and_staff = is_tl_and_staff_setting?(old_setting)

    valid_auto_groups =
      self.public_send("#{new_setting}_map") &
        # We only want auto groups, no actual groups because they cannot be
        # mapped to TLs.
        Group.auto_groups_between(tl_and_staff ? :admins : :trust_level_0, :trust_level_4)

    # We don't want to return nil because this could lead to permission holes;
    # so we return the max available permission in this case.
    return tl_and_staff ? "admin" : TrustLevel[4] if valid_auto_groups.empty?

    if tl_and_staff
      valid_auto_groups_excluding_staff_and_admins =
        valid_auto_groups -
          [Group::AUTO_GROUPS[:staff], Group::AUTO_GROUPS[:admins], Group::AUTO_GROUPS[:moderators]]

      if valid_auto_groups_excluding_staff_and_admins.any?
        return valid_auto_groups_excluding_staff_and_admins.min - Group::AUTO_GROUPS[:trust_level_0]
      end

      if valid_auto_groups.include?(Group::AUTO_GROUPS[:moderators])
        "moderator"
      elsif valid_auto_groups.include?(Group::AUTO_GROUPS[:staff])
        "staff"
      elsif valid_auto_groups.include?(Group::AUTO_GROUPS[:admins])
        "admin"
      end
    else
      valid_auto_groups.min - Group::AUTO_GROUPS[:trust_level_0]
    end
  end

  def tl_to_group(old_setting, val)
    tl_and_staff = is_tl_and_staff_setting?(old_setting)

    if val == "admin"
      Group::AUTO_GROUPS[:admins]
    elsif val == "staff"
      Group::AUTO_GROUPS[:staff]
    else
      if tl_and_staff
        "#{Group::AUTO_GROUPS[:admins]}|#{Group::AUTO_GROUPS[:staff]}|#{val.to_i + Group::AUTO_GROUPS[:trust_level_0]}"
      else
        "#{val.to_i + Group::AUTO_GROUPS[:trust_level_0]}"
      end
    end
  end

  def is_tl_and_staff_setting?(old_setting)
    SiteSetting.type_supervisor.get_type(old_setting.to_sym) == :enum &&
      SiteSetting.type_supervisor.get_enum_class(old_setting.to_sym).name ==
        TrustLevelAndStaffSetting.name
  end

  def setup_deprecated_methods
    SETTINGS.each { |s| setup_deprecated_method(*s) }
  end

  def setup_deprecated_method(old_setting, new_setting, override, version)
    SiteSetting.singleton_class.alias_method(:"_#{old_setting}", :"#{old_setting}") if !override

    if OVERRIDE_TL_GROUP_SETTINGS.include?(old_setting)
      define_singleton_method "_group_to_tl_#{old_setting}" do |warn: true|
        group_to_tl(old_setting, new_setting)
      end
    end

    define_singleton_method old_setting do |scoped_to = nil, warn: true|
      if warn
        Discourse.deprecate(
          "`SiteSetting.#{old_setting}` has been deprecated. Please use `SiteSetting.#{new_setting}` instead.",
          drop_from: version,
        )
      end

      if OVERRIDE_TL_GROUP_SETTINGS.include?(old_setting)
        self.public_send("_group_to_tl_#{old_setting}")
      else
        self.public_send(override ? new_setting : "_#{old_setting}", scoped_to)
      end
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

      if OVERRIDE_TL_GROUP_SETTINGS.include?(old_setting)
        # We want to set both the new group setting here to the equivalent of the
        # TL, as well as setting the TL value in the DB so they remain in sync.
        self.public_send("_#{old_setting}=", val)
        self.public_send("#{new_setting}=", tl_to_group(old_setting, val).to_s)
      else
        self.public_send("#{override ? new_setting : "_" + old_setting}=", val)
      end
    end
  end
end
