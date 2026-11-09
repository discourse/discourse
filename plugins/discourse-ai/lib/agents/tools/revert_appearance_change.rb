# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      # Switches the site back from a live appearance change to what it
      # replaced, once an administrator approves it.
      class RevertAppearanceChange < AppearanceChangeTool
        def self.name
          "revert_appearance_change"
        end

        def self.signature
          {
            name:,
            description:
              "Requests approval to switch back from a live appearance change to the palettes, fonts and default theme it replaced.",
            parameters: [
              {
                name: "appearance_change_id",
                type: "integer",
                required: true,
                description: "The ID of a live change, from list_appearance_changes",
              },
            ],
          }
        end

        def approval_title
          return I18n.t("discourse_ai.appearance_authoring.not_found") if appearance_change.nil?

          I18n.t(
            "discourse_ai.ai_bot.chat_tool_approval.revert_appearance_title",
            name: appearance_change.name,
          )
        end

        def approval_changes
          return [] if appearance_change.nil?

          changes =
            AppearanceAuthoring.color_changes(
              before: AppearanceAuthoring.change_palettes(appearance_change),
              after: previous_palettes,
            )
          changes += AppearanceAuthoring.font_changes(previous_state["site_settings"])
          if appearance_change.kind_theme?
            changes << AppearanceAuthoring.default_theme_change(
              from: appearance_change.theme,
              to: previous_default_theme,
            )
          end
          changes
        end

        def approval_details
          return I18n.t("discourse_ai.appearance_authoring.not_found") if appearance_change.nil?

          I18n.t(
            "discourse_ai.ai_bot.chat_tool_approval.revert_appearance_details",
            name: appearance_change.name,
          )
        end

        def approval_question
          I18n.t("discourse_ai.ai_bot.chat_tool_approval.revert_appearance_question")
        end

        def validation_error
          refusal = AppearanceAuthoring.denial(user: context.user, phase: execution_phase)
          return error_response(refusal) if refusal
          if appearance_change.nil?
            return error_response(I18n.t("discourse_ai.appearance_authoring.not_found"))
          end
          if !appearance_change.applied?
            return error_response(I18n.t("discourse_ai.appearance_authoring.not_live"))
          end
          if !appearance_change.restorable?
            return error_response(I18n.t("discourse_ai.appearance_authoring.cannot_restore"))
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
              AppearanceChange::Revert.call(
                params: {
                  appearance_change_id: appearance_change.id,
                },
                guardian: context.user.guardian,
              )
            next failure_response(result) if result.failure?

            {
              status: "success",
              message:
                I18n.t(
                  "discourse_ai.appearance_authoring.switched_back",
                  name: appearance_change.name,
                ),
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

        def previous_state
          appearance_change.previous_state
        end

        def previous_default_theme
          Theme.find_by(id: previous_state.dig("site_settings", "default_theme_id"))
        end

        # The palettes switching back restores: the theme's previous palettes,
        # or the previous default theme's.
        def previous_palettes
          if appearance_change.kind_theme?
            return AppearanceAuthoring.theme_palettes(previous_default_theme)
          end

          light = ColorScheme.find_by(id: previous_state["color_scheme_id"])
          dark = ColorScheme.find_by(id: previous_state["dark_color_scheme_id"])
          {
            light:
              AppearanceAuthoring.palette_colors(light) ||
                AppearanceAuthoring.theme_palettes(nil)[:light],
            dark: AppearanceAuthoring.palette_colors(dark),
          }
        end
      end
    end
  end
end
