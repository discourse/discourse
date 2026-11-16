# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      # Makes a saved appearance change live for everyone, once an
      # administrator approves it.
      class ActivateAppearanceChange < AppearanceChangeTool
        def self.name
          "activate_appearance_change"
        end

        def self.signature
          {
            name:,
            description:
              "Requests approval to make a saved appearance change live for everyone: its palettes, its fonts and, for a new theme, making it the default theme. Only when the administrator asks to make it live.",
            parameters: [
              {
                name: "appearance_change_id",
                type: "integer",
                required: true,
                description: "The ID returned by save_appearance_change or list_appearance_changes",
              },
            ],
          }
        end

        def approval_title
          return I18n.t("discourse_ai.appearance_authoring.not_found") if appearance_change.nil?

          I18n.t(
            "discourse_ai.ai_bot.chat_tool_approval.activate_appearance_title",
            name: appearance_change.name,
          )
        end

        def approval_changes
          return [] if appearance_change.nil?

          live_theme = appearance_change.kind_theme? ? Theme.find_default : appearance_change.theme
          changes =
            AppearanceAuthoring.color_changes(
              before: AppearanceAuthoring.theme_palettes(live_theme),
              after: AppearanceAuthoring.change_palettes(appearance_change),
            )
          changes += AppearanceAuthoring.font_changes(appearance_change.site_settings)
          if appearance_change.kind_theme?
            changes << AppearanceAuthoring.default_theme_change(
              from: live_theme,
              to: appearance_change.theme,
            )
          end
          changes
        end

        def approval_details
          return I18n.t("discourse_ai.appearance_authoring.not_found") if appearance_change.nil?

          I18n.t(
            "discourse_ai.ai_bot.chat_tool_approval.activate_appearance_details",
            preview_url: AppearanceAuthoring.preview_url(appearance_change),
          )
        end

        def approval_question
          I18n.t("discourse_ai.ai_bot.chat_tool_approval.activate_appearance_question")
        end

        def validation_error
          refusal = AppearanceAuthoring.denial(user: context.user, phase: execution_phase)
          return error_response(refusal) if refusal
          if appearance_change.nil?
            return error_response(I18n.t("discourse_ai.appearance_authoring.not_found"))
          end
          if appearance_change.applied?
            return error_response(I18n.t("discourse_ai.appearance_authoring.already_live"))
          end
          if !context.user.guardian.can_edit_theme?(appearance_change.theme)
            return error_response(I18n.t("discourse_ai.appearance_authoring.theme_not_editable"))
          end

          nil
        end

        def invoke
          if (error = validation_error)
            return error
          end

          with_approval do
            result =
              AppearanceChange::Activate.call(
                params: {
                  appearance_change_id: appearance_change.id,
                },
                guardian: context.user.guardian,
              )
            next failure_response(result) if result.failure?

            {
              status: "success",
              message:
                I18n.t("discourse_ai.appearance_authoring.live", name: appearance_change.name),
              safe_mode_url: AppearanceAuthoring.safe_mode_url,
            }
          end
        rescue ActiveRecord::ActiveRecordError
          error_response(I18n.t("discourse_ai.appearance_authoring.failed"))
        end

        private

        def appearance_change
          return @appearance_change if defined?(@appearance_change)
          @appearance_change =
            AppearanceChange.includes(:theme).find_by(id: parameters[:appearance_change_id].to_i)
        end

        def approved_parameters?(tool_parameters)
          tool_parameters["appearance_change_id"].to_i == appearance_change&.id
        end
      end
    end
  end
end
