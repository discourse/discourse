# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      # Saves an approved appearance draft without making it live, so the
      # administrator can preview it first.
      class SaveAppearanceChange < AppearanceChangeTool
        SERVICES = {
          "palettes" => AppearanceChange::DraftPalettes,
          "existing_palettes" => AppearanceChange::DraftExistingPalettes,
          "theme" => AppearanceChange::DraftTheme,
        }.freeze
        SERVICE_PARAMS = %i[
          theme_id
          name
          light_colors
          dark_colors
          light_palette_id
          dark_palette_id
          site_settings
        ].freeze

        def self.name
          "save_appearance_change"
        end

        def self.signature
          {
            name:,
            description:
              "Requests approval to save an exact appearance draft without making it live, so the administrator can preview it. Never invent, alter, or reuse the draft token.",
            parameters: [
              {
                name: "draft_token",
                type: "string",
                required: true,
                description: "The draft token returned by generate_appearance_change",
              },
            ],
          }
        end

        def approval_title
          return I18n.t("discourse_ai.appearance_authoring.invalid_draft") if !valid_draft?

          I18n.t(
            "discourse_ai.ai_bot.chat_tool_approval.save_appearance_title.#{draft[:kind]}",
            name: draft[:name],
          )
        end

        def approval_changes
          return [] if !valid_draft?

          # new palettes replace their theme's; a new theme replaces what the
          # site shows now
          live_theme = theme_draft? ? Theme.find_default : target_theme
          AppearanceAuthoring.color_changes(
            before: AppearanceAuthoring.theme_palettes(live_theme),
            after: {
              light: draft[:light_colors],
              dark: draft[:dark_colors],
            },
          ) + AppearanceAuthoring.font_changes(draft[:site_settings])
        end

        def approval_details
          return I18n.t("discourse_ai.appearance_authoring.invalid_draft") if !valid_draft?

          I18n.t("discourse_ai.ai_bot.chat_tool_approval.save_appearance_details.#{draft[:kind]}")
        end

        def approval_question
          I18n.t("discourse_ai.ai_bot.chat_tool_approval.save_appearance_question")
        end

        def validation_error
          refusal =
            AppearanceAuthoring.denial(
              user: context.user,
              phase: execution_phase,
              new_theme: theme_draft?,
              new_palettes: valid_draft? && draft[:kind] == "palettes",
            )
          return error_response(refusal) if refusal
          if !valid_draft?
            return error_response(I18n.t("discourse_ai.appearance_authoring.invalid_draft"))
          end

          if !User.exists?(id: draft[:user_id], admin: true)
            return error_response(I18n.t("discourse_ai.appearance_authoring.requester_not_admin"))
          end
          if context.reviewable_id.blank?
            if draft[:user_id] != context.user.id
              return error_response(I18n.t("discourse_ai.appearance_authoring.not_allowed"))
            end
            parameters[:requester_id] = draft[:user_id]
          end

          if !theme_draft? && !context.user.guardian.can_edit_theme?(target_theme)
            return error_response(I18n.t("discourse_ai.appearance_authoring.theme_not_editable"))
          end

          nil
        end

        def invoke
          if (error = validation_error)
            return error
          end

          with_approval do |reviewable|
            if !AppearanceAuthoring::Draft.claim(draft_token, reviewable_id: reviewable.id)
              next error_response(I18n.t("discourse_ai.appearance_authoring.draft_used"))
            end

            save(reviewable)
          end
        rescue ActiveRecord::ActiveRecordError
          error_response(I18n.t("discourse_ai.appearance_authoring.failed"))
        end

        private

        def save(reviewable)
          result =
            SERVICES.fetch(draft[:kind]).call(
              params: draft.slice(*SERVICE_PARAMS),
              guardian: context.user.guardian,
            )
          if result.failure?
            AppearanceAuthoring::Draft.release(draft_token, reviewable_id: reviewable.id)
            return failure_response(result)
          end

          appearance_change = result[:appearance_change]
          AppearanceAuthoring::Draft.complete_after_transaction(
            draft_token,
            reviewable_id: reviewable.id,
            resource_id: appearance_change.id,
          )

          {
            status: "success",
            appearance_change_id: appearance_change.id,
            name: appearance_change.name,
            preview_url: AppearanceAuthoring.preview_url(appearance_change),
            message: I18n.t("discourse_ai.appearance_authoring.saved"),
          }
        rescue StandardError
          AppearanceAuthoring::Draft.release(draft_token, reviewable_id: reviewable.id)
          raise
        end

        def approved_parameters?(tool_parameters)
          tool_parameters["draft_token"] == draft_token &&
            tool_parameters["requester_id"].to_i == draft&.dig(:user_id)
        end

        def draft_token
          parameters[:draft_token].to_s
        end

        def draft
          return @draft if defined?(@draft)
          @draft = AppearanceAuthoring::Draft.read(draft_token)
        end

        # Drafts of existing palettes carry their colors too, for the approval
        # card.
        def valid_draft?
          draft.present? && SERVICES.key?(draft[:kind]) && draft[:name].present? &&
            draft[:light_colors].is_a?(Hash) && draft[:dark_colors].is_a?(Hash) &&
            (
              draft[:kind] != "existing_palettes" ||
                [draft[:light_palette_id], draft[:dark_palette_id]].all?(Integer)
            )
        end

        def theme_draft?
          valid_draft? && draft[:kind] == "theme"
        end

        def target_theme
          Theme.find_by(id: draft[:theme_id], component: false)
        end
      end
    end
  end
end
