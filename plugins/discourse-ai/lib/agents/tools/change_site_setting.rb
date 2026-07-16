# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class ChangeSiteSetting < Tool
        # Upload-backed values cannot be expressed reliably as a string
        # parameter (an unknown URL silently resolves to an empty value),
        # so they stay admin-UI only.
        UNSUPPORTED_TYPES = %i[upload uploaded_image_list].freeze

        UPDATE_POLICIES = %i[
          settings_are_not_deprecated
          settings_are_unshadowed_globally
          settings_are_visible
          settings_are_configurable
        ].freeze

        def self.signature
          {
            name: name,
            description:
              "Changes the value of a site setting. Look up the exact setting name first (e.g. with the search_settings tool); never guess it.",
            parameters: [
              {
                name: "setting_name",
                description: "The exact name of the site setting to change",
                type: "string",
                required: true,
              },
              {
                name: "value",
                description:
                  "The new value for the setting, as a string. Use 'true' or 'false' for boolean settings, plain digits for numeric settings, and pipe-delimited entries (one|two|three) for list settings.",
                type: "string",
                required: true,
              },
              {
                name: "reason",
                description: "Short explanation of why the setting is being changed",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "change_site_setting"
        end

        def self.requires_approval?
          true
        end

        def self.attribute_to_approver?
          true
        end

        def invoke
          if (error = validation_error)
            return error
          end
          perform_update
        end

        # Mirrors the SiteSetting::Update policies (which stay authoritative at
        # write time) so an unknown, hidden, or otherwise unchangeable setting
        # never creates a review item that could only fail on approval.
        def validation_error
          if !guardian.is_admin?
            return(
              error_response(I18n.t("discourse_ai.ai_bot.change_site_setting.errors.not_allowed"))
            )
          end

          if reason.blank?
            return(
              error_response(I18n.t("discourse_ai.ai_bot.change_site_setting.errors.no_reason"))
            )
          end

          if (deprecation = hard_deprecation)
            return(
              error_response(
                I18n.t(
                  "discourse_ai.ai_bot.change_site_setting.errors.deprecated",
                  setting_name: setting_name,
                  new_name: deprecation[1],
                ),
              )
            )
          end

          if !SiteSetting.has_setting?(setting_name)
            return(
              error_response(
                I18n.t(
                  "discourse_ai.ai_bot.change_site_setting.errors.not_found",
                  setting_name: setting_name,
                ),
              )
            )
          end

          if SiteSetting.hidden_settings.include?(setting_sym)
            return(
              error_response(
                I18n.t(
                  "discourse_ai.ai_bot.change_site_setting.errors.hidden",
                  setting_name: setting_name,
                ),
              )
            )
          end

          if SiteSetting.shadowed_settings.include?(setting_sym)
            return(
              error_response(
                I18n.t(
                  "discourse_ai.ai_bot.change_site_setting.errors.shadowed",
                  setting_name: setting_name,
                ),
              )
            )
          end

          if unconfigurable_plugin_setting?
            return(
              error_response(
                I18n.t(
                  "discourse_ai.ai_bot.change_site_setting.errors.unconfigurable",
                  setting_name: setting_name,
                ),
              )
            )
          end

          if UNSUPPORTED_TYPES.include?(setting_type)
            return(
              error_response(
                I18n.t(
                  "discourse_ai.ai_bot.change_site_setting.errors.unsupported_type",
                  type: setting_type,
                ),
              )
            )
          end

          if (error_message = invalid_value_message)
            return(
              error_response(
                I18n.t(
                  "discourse_ai.ai_bot.change_site_setting.errors.invalid_value",
                  error: error_message,
                ),
              )
            )
          end

          nil
        end

        def description_args
          { setting_name: setting_name, value: new_value }
        end

        private

        def setting_name
          parameters[:setting_name].to_s.strip
        end

        def setting_sym
          setting_name.to_sym
        end

        def new_value
          parameters[:value].to_s.strip
        end

        def setting_type
          SiteSetting.type_supervisor.get_type(setting_sym)
        end

        def hard_deprecation
          SiteSettings::DeprecatedSettings::SETTINGS.find do |old_name, _new_name, override, _|
            old_name.to_sym == setting_sym && !override
          end
        end

        def unconfigurable_plugin_setting?
          plugin_name = SiteSetting.plugins[setting_sym]
          plugin_name && !Discourse.plugins_by_name[plugin_name].configurable?
        end

        # Runs the same coercion + validation the SiteSetting::Update service
        # applies at write time, without writing anything.
        def invalid_value_message
          coerced =
            case setting_type
            when :integer
              new_value.tr("^-0-9", "").to_i
            when :file_size_restriction
              new_value.tr("^0-9", "").to_i
            else
              new_value
            end

          SiteSetting.type_supervisor.to_db_value(setting_sym, coerced)
          nil
        rescue Discourse::InvalidParameters => e
          e.message
        end

        def perform_update
          if !guardian.is_admin?
            return(
              error_response(I18n.t("discourse_ai.ai_bot.change_site_setting.errors.not_allowed"))
            )
          end

          result =
            begin
              SiteSetting::Update.call(
                guardian: guardian,
                params: {
                  settings: [{ setting_name: setting_name, value: new_value }],
                },
              )
            rescue Discourse::InvalidParameters => e
              return(
                error_response(
                  I18n.t(
                    "discourse_ai.ai_bot.change_site_setting.errors.invalid_value",
                    error: e.message,
                  ),
                )
              )
            end

          return error_response(update_error_message(result)) if result.failure?

          {
            status: "success",
            message:
              I18n.t(
                "discourse_ai.ai_bot.change_site_setting.success",
                setting_name: setting_name,
                value: new_value,
              ),
          }
        end

        def update_error_message(result)
          contract_result = result["result.contract.default"]
          return contract_result.errors.full_messages.to_sentence if contract_result&.failure?

          if result["result.policy.current_user_is_admin"]&.failure?
            return I18n.t("discourse_ai.ai_bot.change_site_setting.errors.not_allowed")
          end

          UPDATE_POLICIES.each do |policy_name|
            policy_result = result["result.policy.#{policy_name}"]
            next if !policy_result&.failure?
            return policy_result.reason if policy_result.reason.present?
            return I18n.t("discourse_ai.ai_bot.change_site_setting.errors.failed")
          end

          save_error = result["result.step.save"]&.exception&.message
          return save_error if save_error.present?

          I18n.t("discourse_ai.ai_bot.change_site_setting.errors.failed")
        end
      end
    end
  end
end
