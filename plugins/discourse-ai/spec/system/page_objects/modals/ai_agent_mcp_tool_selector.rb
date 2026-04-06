# frozen_string_literal: true

module PageObjects
  module Modals
    class AiAgentMcpToolSelector < PageObjects::Modals::Base
      BODY_SELECTOR = ".ai-agent-mcp-tools-modal__body"
      MODAL_SELECTOR = ".ai-agent-mcp-tools-modal"

      def toggle_tool(tool_name)
        tool_checkbox(tool_name).click
        self
      end

      def has_tool_selected?(tool_name)
        tool_checkbox(tool_name).checked?
      end

      def has_tool_unselected?(tool_name)
        !tool_checkbox(tool_name).checked?
      end

      def has_selection_summary?(count, total)
        body.has_css?(
          ".ai-agent-mcp-tools-modal__selection-summary",
          text:
            I18n.t("js.discourse_ai.ai_agent.mcp_tools_modal.selection_summary", count:, total:),
        )
      end

      private

      def tool_checkbox(tool_name)
        body.find("[data-tool-name='#{tool_name}'] input[type='checkbox']", visible: :all)
      end
    end
  end
end
