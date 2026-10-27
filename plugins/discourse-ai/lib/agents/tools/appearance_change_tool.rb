# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      # The Admin Assistant tools that save, make live or switch back a change
      # to the site's appearance. Each needs an administrator's approval and
      # runs as the approver.
      class AppearanceChangeTool < Tool
        # Why an appearance service can fail, and what to tell the administrator.
        FAILED_POLICIES = {
          can_create_theme: "themes_unavailable",
          local_themes_allowed: "themes_unavailable",
          can_create_color_scheme: "palette_limit",
          can_edit_theme: "theme_not_editable",
          not_applied: "already_live",
          applied: "not_live",
          palettes_exist: "palettes_missing",
          restorable: "cannot_restore",
        }.freeze

        def self.requires_approval?
          true
        end

        def self.mandatory_approval?
          true
        end

        def self.attribute_to_approver?
          true
        end

        def self.available_for_context?(context)
          AppearanceAuthoring.visible?(context&.user)
        end

        def details
          summary
        end

        def approval_parameters
          []
        end

        private

        def execution_phase
          context.reviewable_id.present? ? :approval : :request
        end

        # Runs the block while holding the pending review item that approved
        # this exact call, so a second approval can't run it again.
        def with_approval
          reviewable = approving_reviewable
          return approval_required if reviewable.nil?

          reviewable.with_lock do
            return approval_required if !reviewable.pending?
            yield reviewable
          end
        end

        def approving_reviewable
          return if context.reviewable_id.blank?

          reviewable = ReviewableAiToolAction.find_by(id: context.reviewable_id)
          action = reviewable&.target
          return if action&.tool_name != self.class.name

          reviewable if approved_parameters?(action.tool_parameters)
        end

        def approved_parameters?(_tool_parameters)
          true
        end

        def approval_required
          error_response(I18n.t("discourse_ai.appearance_authoring.approval_required"))
        end

        def failure_response(result)
          policy, = FAILED_POLICIES.find { |name, _| result["result.policy.#{name}"]&.failure? }
          key =
            if policy
              FAILED_POLICIES[policy]
            elsif result["result.model.appearance_change"]&.failure?
              "not_found"
            else
              "failed"
            end
          error_response(I18n.t("discourse_ai.appearance_authoring.#{key}"))
        end
      end
    end
  end
end
