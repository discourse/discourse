# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminAiAgent < PageObjects::Pages::Base
      def visit_edit(agent)
        page.visit("/admin/plugins/discourse-ai/ai-agents/#{agent.id}/edit")
        self
      end

      def form
        @form ||= PageObjects::Components::FormKit.new("form")
      end

      def select_mcp_server(server)
        mcp_server_selector.expand
        mcp_server_selector.search(server.name)
        mcp_server_selector.select_row_by_name(server.name)
        mcp_server_selector.collapse
        self
      end

      def open_mcp_tool_selector(server_name)
        find_mcp_server_item(server_name).find(".ai-agent-editor__mcp-server-action").click
        self
      end

      def has_mcp_server_summary?(server_name, summary_text)
        find_mcp_server_item(server_name).has_text?(summary_text)
      end

      def has_mcp_server_action?(server_name, label)
        find_mcp_server_item(server_name).has_css?(
          ".ai-agent-editor__mcp-server-action",
          text: label,
        )
      end

      private

      def mcp_server_selector
        PageObjects::Components::SelectKit.new("#control-mcp_server_ids .select-kit")
      end

      def find_mcp_server_item(server_name)
        page.find(".ai-agent-editor__mcp-server-item", text: server_name)
      end
    end
  end
end
