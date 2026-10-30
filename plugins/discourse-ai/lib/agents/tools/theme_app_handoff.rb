# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      # Helps an administrator build a theme with their own AI app through the
      # site's MCP server: what still has to be turned on, how to connect
      # their app, whether it connected, and a first message to send it.
      # Changes nothing.
      class ThemeAppHandoff < Tool
        MAX_REQUEST_LENGTH = 2_000

        def self.name
          "theme_app_handoff"
        end

        def self.signature
          {
            name:,
            description:
              "For theme changes beyond colors and fonts, such as layout, HTML or JavaScript: explains how to build them with the administrator's own AI app through this site's MCP server. Reports what still has to be turned on, setup steps for their app, which apps are connected and their latest theme changes, and a first message to send the app. Changes nothing.",
            parameters: [
              {
                name: "app",
                type: "string",
                enum: McpThemeAccess::APPS,
                description: "The AI app the administrator uses, when known",
              },
              {
                name: "request",
                type: "string",
                description: "What the administrator wants the theme to do, in their words",
              },
            ],
          }
        end

        def self.custom_system_message
          <<~TEXT
            When an administrator wants a theme change you can't make yourself, such as changing the layout, adding HTML or JavaScript, or building a theme component, first suggest a built-in option from theme_app_handoff's built_in_options if one fits. Otherwise explain they can build it with their own AI app, such as Claude or ChatGPT, through this site's MCP server, and call theme_app_handoff. If setup_needed is present, explain what it lists and offer enable_mcp_theme_access, which needs approval. Ask which app they use before giving steps, then give only that app's steps exactly as returned. When they say they've connected, call theme_app_handoff again and confirm from connections. Offer the starter_message for them to paste into the app. Changes apps make are live straight away and aren't checked like yours, so remind them to work on a new theme and preview it before making it the default.
          TEXT
        end

        def self.available_for_context?(context)
          McpThemeAccess.visible?(context&.user)
        end

        def invoke
          refusal = McpThemeAccess.denial(user: context.user, phase: :generation)
          return error_response(refusal) if refusal

          {
            status: McpThemeAccess.ready? ? "ready" : "needs_setup",
            mcp_url: DiscourseMcp.resource_url,
            setup_needed: setup_needed.presence,
            blocked_tools: blocked_tools.presence,
            sign_in_notes: McpThemeAccess.sign_in_notes.presence,
            apps: app.nil? ? McpThemeAccess::APPS.map { |key| McpThemeAccess.app_name(key) } : nil,
            app_steps: app && McpThemeAccess.app_steps(app, site_name: SiteSetting.title),
            connections: McpThemeAccess.connections(context.user),
            recent_theme_changes: McpThemeAccess.recent_theme_calls(context.user),
            starter_message:,
            built_in_options:,
            manage: {
              your_connected_apps:
                "#{Discourse.base_url}/u/#{context.user.encoded_username}/preferences/mcp-authorizations",
              all_connections: "#{Discourse.base_url}/admin/config/mcp/authorizations",
              tools_apps_can_use: "#{Discourse.base_url}/admin/config/mcp/capabilities",
            },
          }.compact
        end

        def summary
          I18n.t("discourse_ai.ai_bot.tool_summary.theme_app_handoff")
        end

        def details
          summary
        end

        private

        def app
          value = parameters[:app].to_s
          value if McpThemeAccess::APPS.include?(value)
        end

        def request_text
          parameters[:request].to_s.squish.truncate(MAX_REQUEST_LENGTH).presence
        end

        def setup_needed
          McpThemeAccess.changes.map do |change|
            tools = change.key == :tools ? change.after : []
            I18n.t(
              "discourse_ai.mcp_theme_access.setup.#{change.key}",
              tools: tools.map { |id| McpThemeAccess.tool_title(id) }.join(", "),
            )
          end
        end

        def blocked_tools
          McpThemeAccess.blocked_theme_tool_ids.map do |primitive_id|
            I18n.t(
              "discourse_ai.mcp_theme_access.blocked_tool",
              tool: McpThemeAccess.tool_title(primitive_id),
              url: "#{Discourse.base_url}/admin/config/mcp/capabilities",
            )
          end
        end

        def starter_message
          theme = Theme.find_default
          I18n.t(
            "discourse_ai.mcp_theme_access.starter_message",
            site_url: Discourse.base_url,
            theme: theme&.name || I18n.t("discourse_ai.mcp_theme_access.none"),
            request: request_text || I18n.t("discourse_ai.mcp_theme_access.request_placeholder"),
          )
        end

        def built_in_options
          %w[
            welcome_banner
            sidebar_sections
            banner_topic
            global_notice
            theme_components
          ].to_h do |key|
            [
              key,
              I18n.t("discourse_ai.mcp_theme_access.built_in.#{key}", base_url: Discourse.base_url),
            ]
          end
        end
      end
    end
  end
end
