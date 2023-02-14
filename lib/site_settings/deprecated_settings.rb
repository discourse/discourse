# frozen_string_literal: true

module SiteSettings
end

module SiteSettings::DeprecatedSettings
  SETTINGS = [
    # [<old setting>, <new_setting>, <override>, <version to drop>]
    ["search_tokenize_chinese_japanese_korean", "search_tokenize_chinese", true, "2.9"],
    ["default_categories_regular", "default_categories_normal", true, "3.0"],
    ["min_trust_to_send_messages", "personal_message_enabled_groups", false, "3.0"],
    ["enable_personal_messages", "personal_message_enabled_groups", false, "3.0"],
  ]

  def setup_deprecated_methods
    SETTINGS.each do |old_setting, new_setting, override, version|
      unless override
        SiteSetting.singleton_class.public_send(
          :alias_method,
          :"_#{old_setting}",
          :"#{old_setting}",
        )
      end

      define_singleton_method old_setting do |warn: true|
        if warn
          Discourse.deprecate(
            "`SiteSetting.#{old_setting}` has been deprecated. Please use `SiteSetting.#{new_setting}` instead.",
            drop_from: version,
          )
        end

        self.public_send(override ? new_setting : "_#{old_setting}")
      end

      unless override
        SiteSetting.singleton_class.public_send(
          :alias_method,
          :"_#{old_setting}?",
          :"#{old_setting}?",
        )
      end

      define_singleton_method "#{old_setting}?" do |warn: true|
        if warn
          Discourse.deprecate(
            "`SiteSetting.#{old_setting}?` has been deprecated. Please use `SiteSetting.#{new_setting}?` instead.",
            drop_from: version,
          )
        end

        self.public_send("#{override ? new_setting : "_" + old_setting}?")
      end

      unless override
        SiteSetting.singleton_class.public_send(
          :alias_method,
          :"_#{old_setting}=",
          :"#{old_setting}=",
        )
      end

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
end
