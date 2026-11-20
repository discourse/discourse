# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      # Installs a theme from core's list of popular themes, once an
      # administrator approves it, without making it live, so it can be
      # previewed first. It's saved as an appearance change, so
      # activate_appearance_change makes it live and revert_appearance_change
      # switches back.
      class InstallPopularTheme < AppearanceChangeTool
        def self.name
          "install_popular_theme"
        end

        def self.signature
          themes =
            PopularThemes
              .themes
              .map { |entry| "- #{entry[:id]}: #{entry[:name]}. #{entry[:description]}" }
              .join("\n")

          {
            name:,
            description: <<~DESCRIPTION.strip,
              Requests approval to install a ready-made theme maintained by Discourse, without making it live, so the administrator can preview it. Use it when they want a different design rather than new colors or styles, or ask what themes they could use. Each one brings its own layout and palettes. Available themes:
              #{themes}
            DESCRIPTION
            parameters: [
              {
                name: "theme",
                type: "string",
                enum: PopularThemes.themes.map { |entry| entry[:id] },
                required: true,
                description: "The theme to install",
              },
            ],
          }
        end

        def self.custom_system_message
          <<~TEXT
            When an administrator wants a different design rather than new colors or styles, or asks which themes they could use, describe the ready-made themes install_popular_theme offers, using their names and descriptions as given and never their ids, and suggest the ones that fit. Only call it once they've chosen one, or when they name a theme themselves. It also works for one of these themes the site already has, without installing it again. Installing or saving needs approval and doesn't change the site. Once it's saved, share the preview link and ask whether to make it live with activate_appearance_change, using the returned appearance_change_id. Its layout and palettes replace the current theme's.
          TEXT
        end

        def approval_title
          return I18n.t("discourse_ai.appearance_authoring.not_popular") if popular_theme.nil?

          I18n.t(
            "discourse_ai.ai_bot.chat_tool_approval.#{approval_key}_title",
            name: installed_theme&.name || popular_theme[:name],
          )
        end

        def approval_changes
          []
        end

        def approval_details
          return I18n.t("discourse_ai.appearance_authoring.not_popular") if popular_theme.nil?

          I18n.t(
            "discourse_ai.ai_bot.chat_tool_approval.#{approval_key}_details",
            description: popular_theme[:description],
            remote_url: popular_theme[:remote_url],
            name: installed_theme&.name,
          )
        end

        def approval_question
          I18n.t("discourse_ai.ai_bot.chat_tool_approval.#{approval_key}_question")
        end

        def validation_error
          if popular_theme.nil?
            refusal = AppearanceAuthoring.denial(user: context.user, phase: execution_phase)
            return error_response(refusal) if refusal
            return error_response(I18n.t("discourse_ai.appearance_authoring.not_popular"))
          end
          # a theme the site already has isn't a new one
          refusal =
            AppearanceAuthoring.denial(
              user: context.user,
              phase: execution_phase,
              new_theme: installed_theme.nil?,
            )
          return error_response(refusal) if refusal
          if installed_theme&.default?
            return(
              error_response(
                I18n.t(
                  "discourse_ai.appearance_authoring.already_default",
                  name: installed_theme.name,
                ),
              )
            )
          end
          if installed_theme && !context.user.guardian.can_edit_theme?(installed_theme)
            return error_response(I18n.t("discourse_ai.appearance_authoring.theme_not_editable"))
          end

          nil
        end

        def invoke
          if (error = validation_error)
            return error
          end

          with_approval do
            existing = installed_theme.present?
            result =
              AppearanceChange::InstallTheme.call(
                params: {
                  remote_url: popular_theme[:remote_url],
                },
                guardian: context.user.guardian,
              )
            next failure_response(result) if result.failure?

            appearance_change = result[:appearance_change]
            {
              status: "success",
              appearance_change_id: appearance_change.id,
              name: appearance_change.name,
              preview_url: AppearanceAuthoring.preview_url(appearance_change),
              message:
                I18n.t(
                  "discourse_ai.appearance_authoring.#{existing ? "saved_existing_theme" : "installed"}",
                ),
            }
          end
        rescue ActiveRecord::ActiveRecordError
          error_response(I18n.t("discourse_ai.appearance_authoring.failed"))
        end

        private

        def popular_theme
          return @popular_theme if defined?(@popular_theme)
          @popular_theme =
            PopularThemes.themes.find { |entry| entry[:id] == parameters[:theme].to_s }
        end

        # The site's copy of the theme, when it already has one.
        def installed_theme
          return @installed_theme if defined?(@installed_theme)
          url = popular_theme[:remote_url].downcase
          @installed_theme =
            Theme
              .where(component: false)
              .joins(:remote_theme)
              .where("lower(remote_themes.remote_url) IN (?)", [url, "#{url}.git"])
              .order(:id)
              .first
        end

        def approval_key
          installed_theme ? "use_theme" : "install_theme"
        end

        def approved_parameters?(tool_parameters)
          tool_parameters["theme"].to_s == popular_theme&.dig(:id)
        end
      end
    end
  end
end
