# frozen_string_literal: true

module SiteSettings
end

module SiteSettings::DeprecatedSettings
  SETTINGS = [
    # [<old setting>, <new_setting>, <override>, <version to drop>]
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
    ["min_trust_to_allow_self_wiki", "self_wiki_allowed_groups", false, "3.3"],
    ["min_trust_to_create_tag", "create_tag_allowed_groups", false, "3.3"],
    ["min_trust_to_send_email_messages", "send_email_messages_allowed_groups", false, "3.3"],
    ["review_media_unless_trust_level", "skip_review_media_groups", false, "3.3"],
    ["min_trust_to_post_embedded_media", "embedded_media_post_allowed_groups", false, "3.3"],
    ["min_trust_to_post_links", "post_links_allowed_groups", false, "3.3"],
    ["min_trust_level_for_user_api_key", "user_api_key_allowed_groups", false, "3.3"],
    ["min_trust_level_to_tag_topics", "tag_topic_allowed_groups", false, "3.3"],
    [
      "min_trust_level_to_allow_profile_background",
      "profile_background_allowed_groups",
      false,
      "3.3",
    ],
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
    min_trust_to_create_tag
    min_trust_to_send_email_messages
    review_media_unless_trust_level
    min_trust_to_post_embedded_media
    min_trust_to_post_links
    min_trust_level_for_user_api_key
    min_trust_level_to_tag_topics
    min_trust_level_to_allow_profile_background
  ]

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
    SETTINGS.each do |old_setting, new_setting, override, version|
      SiteSetting.singleton_class.alias_method(:"_#{old_setting}", :"#{old_setting}") if !override

      if OVERRIDE_TL_GROUP_SETTINGS.include?(old_setting)
        define_singleton_method "_group_to_tl_#{old_setting}" do |warn: true|
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

      SiteSetting.singleton_class.alias_method(:"_#{old_setting}?", :"#{old_setting}?") if !override

      define_singleton_method "#{old_setting}?" do |warn: true|
        if warn
          Discourse.deprecate(
            "`SiteSetting.#{old_setting}?` has been deprecated. Please use `SiteSetting.#{new_setting}?` instead.",
            drop_from: version,
          )
        end

        self.public_send("#{override ? new_setting : "_" + old_setting}?")
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
end
