# frozen_string_literal: true

module SiteSettings
end

module SiteSettings::DeprecatedSettings
  SETTINGS = [
    # [<old setting>, <new_setting>, <override>, <version to drop>]
    ["search_tokenize_chinese_japanese_korean", "search_tokenize_chinese", true, "2.9"],
    ["default_categories_regular", "default_categories_normal", true, "3.0"],
    ["anonymous_posting_min_trust_level", "anonymous_posting_allowed_groups", false, "3.3"],
    ["shared_drafts_min_trust_level", "shared_drafts_allowed_groups", false, "3.3"],
    ["min_trust_level_for_here_mention", "here_mention_allowed_groups", false, "3.3"],
    ["approve_unless_trust_level", "approve_unless_allowed_groups", false, "3.3"],
    [
      "approve_new_topics_unless_trust_level",
      "approve_new_topics_unless_allowed_groups",
      false,
      "3.3",
    ],
    ["email_in_min_trust", "email_in_allowed_groups", false, "3.3"],
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
