# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class UpdateSetting < Tool
        def self.signature
          {
            name: name,
            description: "Updates a site setting.",
            parameters: [
              {
                name: "setting_name",
                description: "The name of the site setting to update",
                type: "string",
                required: true,
              },
              {
                name: "value",
                description: "The new value for the site setting",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "update_setting"
        end

        def self.requires_approval?
          true
        end

        def self.always_requires_approval?
          true
        end

        def self.attribute_to_approver?
          true
        end

        def setting_name
          @setting_name ||= parameters[:setting_name].to_s.downcase.gsub(" ", "_")
        end

        def invoke
          if !guardian.is_admin?
            return error_response(I18n.t("discourse_ai.ai_bot.update_setting.errors.not_allowed"))
          end

          if !SiteSetting.has_setting?(setting_name)
            return error_response(I18n.t("discourse_ai.ai_bot.update_setting.errors.not_found"))
          end

          SiteSetting.set_and_log(setting_name, parameters[:value], context.user || acting_user)

          { status: "success", message: I18n.t("discourse_ai.ai_bot.update_setting.success") }
        rescue ArgumentError,
               Discourse::InvalidParameters,
               SiteSettingExtension::InvalidSettingAccess
          error_response(I18n.t("discourse_ai.ai_bot.update_setting.errors.invalid_value"))
        end

        def description_args
          { setting_name: setting_name }
        end
      end
    end
  end
end
