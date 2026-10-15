# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      class Plan
        # Decides where each detected change goes. All the adjustable lists
        # live here.
        module Rules
          # Login/SSO configuration that must only exist on the migrated site.
          AUTH_SETTING_PREFIXES = %w[
            openid_connect_
            discourse_connect_
            enable_discourse_connect
            enable_local_logins
            saml_
            oauth2_
            auth_
            ldap_
            jwt_
            google_oauth2_
            github_client_
            facebook_app_
            twitter_consumer_
            discord_client_
            microsoft_client_
            linkedin_oidc_client_
          ].freeze
          AUTH_SETTING_PATTERN = /\Aenable_\w+_logins\z/

          # Provider names as they appear as a segment of login translation keys.
          AUTH_PROVIDER_NAMES = %w[
            oidc
            openid_connect
            saml
            oauth2
            oauth2_basic
            discourse_connect
            sso
            google_oauth2
            github
            facebook
            twitter
            discord
            microsoft_office365
            linkedin_oidc
            apple
            ldap
            jwt
          ].freeze

          # Email, storage and backup setup that differs per hosted site and
          # must not be copied between sites.
          HOSTING_MANAGED_SETTINGS = %w[
            notification_email
            reply_by_email_address
            alternative_reply_by_email_addresses
            reply_by_email_enabled
            manual_polling_enabled
            log_mail_processing_failures
            enable_smtp
            force_https
            allowed_internal_hosts
            enable_s3_uploads
            enable_backups
            backup_location
            backup_frequency
            maximum_backups
          ].freeze
          HOSTING_MANAGED_PREFIXES = %w[pop3_polling_ s3_ backup_].freeze

          IMPORT_SETTING_TYPES = %i[category category_list topic username].freeze
          GROUP_SETTING_TYPES = %i[group group_list].freeze

          GROUP_ATTRIBUTES = %w[
            full_name
            title
            bio_raw
            flair_icon
            flair_upload_id
            flair_bg_color
            flair_color
            primary_group
            grant_trust_level
            automatic_membership_email_domains
            visibility_level
            members_visibility_level
            mentionable_level
            messageable_level
            assignable_level
            allow_membership_requests
            membership_request_template
            public_admission
            public_exit
            default_notification_level
            publish_read_state
          ].freeze

          CATEGORY_ATTRIBUTES = %w[
            name
            description
            color
            text_color
            style_type
            emoji
            icon
            position
            uploaded_logo_id
            uploaded_logo_dark_id
            uploaded_background_id
            uploaded_background_dark_id
            topic_template
            sort_order
            sort_ascending
            default_view
            default_top_period
            default_list_filter
            subcategory_list_style
            show_subcategory_list
            num_featured_topics
          ].freeze

          # Plan attribute names for id columns whose values travel as uploads.
          UPLOAD_ATTRIBUTES = {
            "flair_upload_id" => "flair_upload",
            "uploaded_logo_id" => "uploaded_logo",
            "uploaded_logo_dark_id" => "uploaded_logo_dark",
            "uploaded_background_id" => "uploaded_background",
            "uploaded_background_dark_id" => "uploaded_background_dark",
          }.freeze

          # Columns that change on their own and never indicate a user edit.
          NOISE_COLUMNS = %w[
            updated_at
            created_at
            version
            compiler_version
            value_baked
            error
            user_count
            bio_cooked
          ].freeze

          THEME_SCREENSHOT_FIELD_TYPE = "7"

          # Not a column: the category's group permissions as a whole.
          CATEGORY_PERMISSIONS = "permissions"

          class << self
            # @return [Hash] `target`, optional `note` and `secret`
            def site_setting(name, value, facts)
              info = facts.site_setting(name)
              return skip("unknown setting") if info.nil?
              if info[:themeable]
                return skip("themeable: transferred with the theme's site settings")
              end
              return skip("hosting-managed") if hosting_managed?(name)
              return skip("hidden") if info[:hidden]
              return skip("overridden by a global setting") if info[:global]

              secret = info[:secret] || Secrets.secret_name?(name)
              result =
                if auth_setting?(name)
                  { "target" => "migrated", "note" => "login/SSO" }
                elsif IMPORT_SETTING_TYPES.include?(info[:type])
                  { "target" => "migrated", "note" => "references imported data" }
                elsif GROUP_SETTING_TYPES.include?(info[:type]) && custom_groups?(value, facts)
                  { "target" => "migrated", "note" => "references non-automatic groups" }
                elsif secret
                  { "target" => "migrated", "note" => "secret" }
                else
                  { "target" => "template" }
                end
              result["secret"] = true if secret
              result
            end

            def hosting_managed?(name)
              HOSTING_MANAGED_SETTINGS.include?(name) ||
                HOSTING_MANAGED_PREFIXES.any? { |prefix| name.start_with?(prefix) }
            end

            def auth_setting?(name)
              AUTH_SETTING_PREFIXES.any? { |prefix| name.start_with?(prefix) } ||
                AUTH_SETTING_PATTERN.match?(name)
            end

            def translation_override(key)
              segments = key.split(".")
              if segments.include?("login") && (segments & AUTH_PROVIDER_NAMES).any?
                { "target" => "migrated", "note" => "login/SSO" }
              else
                { "target" => "template" }
              end
            end

            def group(info)
              return { "target" => "template" } if info[:automatic]
              return { "target" => "migrated", "note" => "imported group" } if info[:imported]

              { "target" => "template", "note" => "created on this site; created if missing" }
            end

            def category(info)
              return { "target" => "migrated", "note" => "imported category" } if info[:imported]

              { "target" => "template", "note" => "created on this site; created if missing" }
            end

            # The UI saves empty fields as "" where they were NULL before.
            def blank_equal?(a, b)
              (a.nil? || a == "") && (b.nil? || b == "")
            end

            def plan_attribute_name(column)
              UPLOAD_ATTRIBUTES.fetch(column, column)
            end

            private

            def skip(note)
              { "target" => "skip", "note" => note }
            end

            def custom_groups?(value, facts)
              value.to_s.split("|").any? { |id| !facts.automatic_group_id?(id.to_i) }
            end
          end
        end
      end
    end
  end
end
