# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class ReadSiteSetting < Tool
        class << self
          def signature
            {
              name: name,
              description:
                "Returns the current value of a site setting. Look up the exact setting name first (e.g. with the search_settings tool); never guess it.",
              parameters: [
                {
                  name: "setting_name",
                  description: "The exact name of the site setting to read",
                  type: "string",
                  required: true,
                },
              ],
            }
          end

          def name
            "read_site_setting"
          end
        end

        def invoke
          if (validation_result = validation_error)
            return validation_result
          end

          { setting_name: setting_name, value: SiteSetting.get(setting_sym) }
        end

        def validation_error
          if !guardian.is_admin?
            return(
              error_response(I18n.t("discourse_ai.ai_bot.read_site_setting.errors.not_allowed"))
            )
          end

          if !SiteSetting.has_setting?(setting_name)
            return(
              error_response(
                I18n.t(
                  "discourse_ai.ai_bot.read_site_setting.errors.not_found",
                  setting_name: setting_name,
                ),
              )
            )
          end

          if SiteSetting.hidden_settings.include?(setting_sym)
            return(
              error_response(
                I18n.t(
                  "discourse_ai.ai_bot.read_site_setting.errors.hidden",
                  setting_name: setting_name,
                ),
              )
            )
          end

          if SiteSetting.secret_settings.include?(setting_sym)
            return(
              error_response(
                I18n.t(
                  "discourse_ai.ai_bot.read_site_setting.errors.secret",
                  setting_name: setting_name,
                ),
              )
            )
          end

          if SiteSetting.themeable[setting_sym]
            return(
              error_response(
                I18n.t(
                  "discourse_ai.ai_bot.read_site_setting.errors.themeable",
                  setting_name: setting_name,
                ),
              )
            )
          end

          nil
        end

        def description_args
          { setting_name: setting_name }
        end

        private

        def setting_name
          @setting_name ||= parameters[:setting_name].to_s.strip
        end

        def setting_sym
          setting_name.to_sym
        end
      end
    end
  end
end
