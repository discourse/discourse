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
    ["min_trust_to_edit_wiki_post", "edit_wiki_post_allowed_groups", false, "3.3"],
    ["allow_uploaded_avatars", "uploaded_avatars_allowed_groups", false, "3.3"],
    ["min_trust_to_create_topic", "create_topic_allowed_groups", false, "3.3"],
    ["min_trust_to_edit_post", "edit_post_allowed_groups", false, "3.3"],
    ["min_trust_to_flag_posts", "flag_post_allowed_groups", false, "3.3"],
    ["tl4_delete_posts_and_topics", "delete_all_posts_and_topics_allowed_groups", false, "3.3"],
    [
      "min_trust_level_to_allow_user_card_background",
      "user_card_background_allowed_groups",
      false,
      "3.3",
    ],
    ["min_trust_level_to_allow_invite", "invite_allowed_groups", false, "3.3"],
    ["min_trust_level_to_allow_ignore", "ignore_allowed_groups", false, "3.3"],
  ]

  OVERRIDE_TL_GROUP_SETTINGS = %w[
    anonymous_posting_min_trust_level
    shared_drafts_min_trust_level
    min_trust_level_for_here_mention
    approve_unless_trust_level
    approve_new_topics_unless_trust_level
    email_in_min_trust
    min_trust_to_edit_wiki_post
    allow_uploaded_avatars
    min_trust_to_create_topic
    min_trust_to_edit_post
    min_trust_to_flag_posts
    tl4_delete_posts_and_topics
    min_trust_level_to_allow_user_card_background
    min_trust_level_to_allow_invite
    min_trust_level_to_allow_ignore
  ]

  def group_to_tl(old_setting, new_setting)
    tl_and_staff =
      SiteSetting.type_supervisor.get_type(old_setting.to_sym) == :enum &&
        SiteSetting
          .type_supervisor
          .get_enum_class(old_setting.to_sym)
          .is_a?(TrustLevelAndStaffSetting)

    min_trust_from_new_group_values =
      self
        .public_send("#{new_setting}_map")
        .select do |group_id|
          # We only want auto groups, no actual groups because they cannot be
          # mapped to TLs.
          group_id.between?(
            tl_and_staff ? Group::AUTO_GROUPS[:admins] : Group::AUTO_GROUPS[:trust_level_0],
            Group::AUTO_GROUPS[:trust_level_4],
          )
        end
        .min

    if min_trust_from_new_group_values == Group::AUTO_GROUPS[:admin]
      tl_and_staff ? "admin" : nil
    elsif min_trust_from_new_group_values == Group::AUTO_GROUPS[:staff]
      tl_and_staff ? "staff" : nil
    else
      min_trust_from_new_group_values - Group::AUTO_GROUPS[:trust_level_0]
    end
  end

  def tl_to_group(old_setting, val)
    if val == "admin"
      Group::AUTO_GROUPS[:admin]
    elsif val == "staff"
      Group::AUTO_GROUPS[:staff]
    else
      "#{val.to_i + Group::AUTO_GROUPS[:trust_level_0]}"
    end
  end

  def setup_deprecated_methods
    SETTINGS.each do |old_setting, new_setting, override, version|
      unless override
        SiteSetting.singleton_class.public_send(
          :alias_method,
          :"_#{old_setting}",
          :"#{old_setting}",
        )
      end

      if OVERRIDE_TL_GROUP_SETTINGS.include?(old_setting)
        define_singleton_method "_group_to_tl_#{old_setting}" do |warn: true|
          group_to_tl(old_setting, new_setting)
        end

        define_singleton_method "_group_to_tl_#{old_setting}?" do |warn: true|
          group_to_tl(old_setting, new_setting)
        end
      end

      define_singleton_method old_setting do |warn: true|
        if warn
          Discourse.deprecate(
            "`SiteSetting.#{old_setting}` has been deprecated. Please use `SiteSetting.#{new_setting}` instead.",
            drop_from: version,
          )
        end

        if OVERRIDE_TL_GROUP_SETTINGS.include?(old_setting)
          self.public_send("_group_to_tl_#{old_setting}")
        else
          self.public_send(override ? new_setting : "_#{old_setting}")
        end
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

        if OVERRIDE_TL_GROUP_SETTINGS.include?(old_setting)
          # We want to set both the new group setting here to the equivalent of the
          # TL, as well as setting the TL value in the DB so they remain in sync.
          self.public_send("_#{old_setting}=", val)
          self.public_send("#{new_setting}=", tl_to_group(old_setting, val))
        else
          self.public_send("#{override ? new_setting : "_" + old_setting}=", val)
        end
      end
    end
  end
end
