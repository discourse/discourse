# frozen_string_literal: true

module SiteSettings; end

module SiteSettings::DeprecatedSettings
  SETTINGS = [
    ['show_email_on_profile', 'moderators_view_emails', true, '2.4'],
    ['allow_moderators_to_create_categories', 'moderators_create_categories', true, '2.4'],
    ['disable_edit_notifications', 'disable_system_edit_notifications', true, '2.4'],
    ['enable_category_group_review', 'enable_category_group_moderation', true, '2.7'],
    ['newuser_max_images', 'newuser_max_embedded_media', true, '2.7'],
    ['min_trust_to_post_images', 'min_trust_to_post_embedded_media', true, '2.7'],
    ['moderators_create_categories', 'moderators_manage_categories_and_groups', '2.7'],

    ['enable_sso', 'enable_discourse_connect', true, '2.8'],
    ['sso_allows_all_return_paths', 'discourse_connect_allows_all_return_paths', true, '2.8'],
    ['enable_sso_provider', 'enable_discourse_connect_provider', true, '2.8'],
    ['verbose_sso_logging', 'verbose_discourse_connect_logging', true, '2.8'],
    ['sso_url', 'discourse_connect_url', true, '2.8'],
    ['sso_secret', 'discourse_connect_secret', true, '2.8'],
    ['sso_provider_secrets', 'discourse_connect_provider_secrets', true, '2.8'],
    ['sso_overrides_groups', 'discourse_connect_overrides_groups', true, '2.8'],
    ['sso_overrides_bio', 'discourse_connect_overrides_bio', true, '2.8'],
    ['sso_overrides_email', 'auth_overrides_email', true, '2.8'],
    ['sso_overrides_username', 'auth_overrides_username', true, '2.8'],
    ['sso_overrides_name', 'auth_overrides_name', true, '2.8'],
    ['sso_overrides_avatar', 'discourse_connect_overrides_avatar', true, '2.8'],
    ['sso_overrides_profile_background', 'discourse_connect_overrides_profile_background', true, '2.8'],
    ['sso_overrides_location', 'discourse_connect_overrides_location', true, '2.8'],
    ['sso_overrides_website', 'discourse_connect_overrides_website', true, '2.8'],
    ['sso_overrides_card_background', 'discourse_connect_overrides_card_background', true, '2.8'],
    ['external_auth_skip_create_confirm', 'auth_skip_create_confirm', true, '2.8'],
    ['external_auth_immediately', 'auth_immediately', true, '2.8'],
    ['search_tokenize_chinese_japanese_korean', 'search_tokenize_chinese', true, '2.9'],
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
          Discourse.deprecate(
            "`SiteSetting.#{old_setting}` has been deprecated. Please use `SiteSetting.#{new_setting}` instead.",
            drop_from: version
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
          Discourse.deprecate(
            "`SiteSetting.#{old_setting}?` has been deprecated. Please use `SiteSetting.#{new_setting}?` instead.",
            drop_from: version
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
          Discourse.deprecate(
            "`SiteSetting.#{old_setting}=` has been deprecated. Please use `SiteSetting.#{new_setting}=` instead.",
            drop_from: version
          )
        end

        self.public_send("#{override ? new_setting : "_" + old_setting}=", val)
      end
    end
  end
end
