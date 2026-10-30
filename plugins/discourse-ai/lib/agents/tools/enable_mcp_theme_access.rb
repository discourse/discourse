# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      # Turns on what an administrator's AI app needs to build themes through
      # the site's MCP server, once an administrator approves it: the server
      # itself, the theme tools, and theme access for administrators.
      class EnableMcpThemeAccess < Tool
        def self.name
          "enable_mcp_theme_access"
        end

        def self.signature
          {
            name:,
            description:
              "Requests approval to let the administrator's AI apps build themes through this site's MCP server: turns on the MCP server if needed, lets apps use the theme tools, and gives administrators theme access. Only when the administrator asks for it after theme_app_handoff reported setup_needed.",
            parameters: [],
          }
        end

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
          McpThemeAccess.visible?(context&.user)
        end

        def summary
          I18n.t("discourse_ai.ai_bot.tool_summary.enable_mcp_theme_access")
        end

        def details
          summary
        end

        def approval_title
          I18n.t("discourse_ai.ai_bot.chat_tool_approval.enable_mcp_theme_access_title")
        end

        def approval_changes
          McpThemeAccess.changes.map do |change|
            label = I18n.t("discourse_ai.mcp_theme_access.changes.#{change.key}")
            case change.key
            when :server
              { label:, before: off_label, after: on_label }
            when :tools
              {
                label:,
                before: off_label,
                after: change.after.map { |id| McpThemeAccess.tool_title(id) }.join(", "),
              }
            when :admin_scopes
              { label:, before: off_label, after: change.after.join(", ") }
            end
          end
        end

        def approval_details
          I18n.t(
            "discourse_ai.ai_bot.chat_tool_approval.enable_mcp_theme_access_details",
            mcp_url: DiscourseMcp.resource_url,
            settings_url: "#{Discourse.base_url}/admin/config/mcp/capabilities",
          )
        end

        def approval_question
          I18n.t("discourse_ai.ai_bot.chat_tool_approval.enable_mcp_theme_access_question")
        end

        def approval_parameters
          []
        end

        def validation_error
          refusal = McpThemeAccess.denial(user: context.user, phase: execution_phase)
          return error_response(refusal) if refusal
          if McpThemeAccess.ready?
            return error_response(I18n.t("discourse_ai.mcp_theme_access.already_enabled"))
          end
          if !McpThemeAccess.server_enabled? && McpThemeAccess.server_setting_locked?
            return error_response(I18n.t("discourse_ai.mcp_theme_access.server_locked"))
          end

          nil
        end

        def invoke
          if (error = validation_error)
            return error
          end

          reviewable = approving_reviewable
          return approval_required if reviewable.nil?

          reviewable.with_lock do
            return approval_required if !reviewable.pending?

            if !McpThemeAccess.enable!(guardian: context.user.guardian)
              return error_response(I18n.t("discourse_ai.mcp_theme_access.failed"))
            end
          end

          {
            status: "success",
            message: I18n.t("discourse_ai.mcp_theme_access.enabled"),
            mcp_url: DiscourseMcp.resource_url,
          }
        rescue ActiveRecord::ActiveRecordError, Discourse::InvalidParameters
          error_response(I18n.t("discourse_ai.mcp_theme_access.failed"))
        end

        private

        def execution_phase
          context.reviewable_id.present? ? :approval : :request
        end

        def approving_reviewable
          return if context.reviewable_id.blank?

          reviewable = ReviewableAiToolAction.find_by(id: context.reviewable_id)
          reviewable if reviewable&.target&.tool_name == self.class.name
        end

        def approval_required
          error_response(I18n.t("discourse_ai.mcp_theme_access.approval_required"))
        end

        def on_label
          I18n.t("discourse_ai.mcp_theme_access.on")
        end

        def off_label
          I18n.t("discourse_ai.mcp_theme_access.off")
        end
      end
    end
  end
end
