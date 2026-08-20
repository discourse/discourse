# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminAiAgent < PageObjects::Pages::Base
      def visit_list
        page.visit("/admin/plugins/discourse-ai/ai-agents")
        self
      end

      def visit_edit(agent)
        page.visit("/admin/plugins/discourse-ai/ai-agents/#{agent.id}/edit")
        self
      end

      def open_duplicate_menu
        page.find("button.duplicate-agent-menu-trigger").click
        self
      end

      def filter_duplicates(value)
        page.find("[data-test-duplicate-agent-filter]").fill_in(with: value)
        self
      end

      def duplicate_from_list(name)
        page.find("[data-test-duplicate-agent-option]", text: name).click
        self
      end

      def has_duplicate_option?(name)
        page.has_css?("[data-test-duplicate-agent-option]", text: name)
      end

      def has_no_duplicate_option?(name)
        page.has_no_css?("[data-test-duplicate-agent-option]", text: name)
      end

      def duplicate
        page.find(".ai-agent-editor__duplicate").click
        self
      end

      def has_floating_actions?
        page.has_css?(".form-kit__actions.is-floating")
      end

      def has_no_floating_actions?
        page.has_no_css?(".form-kit__actions.is-floating")
      end

      def has_form_field_value?(name, value)
        page.has_field?(name, with: value)
      end

      def has_agent_enabled_state?(enabled)
        page.has_css?(
          ".form-kit__field[data-name='enabled'] button[role='switch'][aria-checked='#{enabled}']",
          visible: :all,
        )
      end

      def has_agent_user?(username = nil)
        options = username ? { text: username } : {}
        page.has_css?(".ai-agent-editor__ai_bot_user a", **options)
      end

      def has_no_agent_user?(username = nil)
        options = username ? { text: username } : {}
        page.has_no_css?(".ai-agent-editor__ai_bot_user a", **options)
      end

      def form
        @form ||= PageObjects::Components::FormKit.new("form")
      end

      def has_no_subagent_option?(agent)
        subagent_selector.expand
        result = subagent_selector.has_no_option_value?(agent.id)
        subagent_selector.collapse
        result
      end

      def has_subagent_selector_disabled?
        page.has_css?("#control-subagent_ids .select-kit.is-disabled")
      end

      def select_subagent(agent)
        subagent_selector.expand
        subagent_selector.select_row_by_value(agent.id)
        subagent_selector.collapse
        self
      end

      def has_selected_subagent?(agent)
        page.has_css?("#control-subagent_ids", text: agent.name)
      end

      def clear_subagents
        subagent_selector.expand
        subagent_selector.clear
        subagent_selector.collapse
        self
      end

      def has_disabled_subagent?(agent)
        page.has_css?(
          "#control-subagent_ids",
          text: I18n.t("js.discourse_ai.ai_agent.subagent_disabled", name: agent.name),
        )
      end

      def has_subagent_summary?(count)
        page.has_css?(
          ".ai-agent-editor__subagent-summary",
          text: I18n.t("js.discourse_ai.ai_agent.subagents_summary", count: count),
        )
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

      def subagent_selector
        PageObjects::Components::SelectKit.new("#control-subagent_ids .select-kit")
      end

      def mcp_server_selector
        PageObjects::Components::SelectKit.new("#control-mcp_server_ids .select-kit")
      end

      def find_mcp_server_item(server_name)
        page.find(".ai-agent-editor__mcp-server-item", text: server_name)
      end
    end
  end
end
