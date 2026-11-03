# frozen_string_literal: true

module DiscourseAi
  module Agents
    # Lets administrators build themes with their own AI apps, through the
    # site's MCP server, when what they want goes beyond what the Admin
    # Assistant changes itself: works out what's missing, turns on what's
    # needed, and checks that an app connected.
    module McpThemeAccess
      FEATURE = :mcp_theme_access

      THEME_TOOL_IDS = %w[
        tool:discourse_get_theme
        tool:discourse_create_theme
        tool:discourse_update_theme
      ].freeze
      THEME_SCOPES = [DiscourseMcp::Scopes::THEMES_READ, DiscourseMcp::Scopes::THEMES_WRITE].freeze
      SERVER_SETTING = :mcp_server_enabled

      RECENT_CALLS = 5

      Change = Data.define(:key, :before, :after)

      def self.visible?(user)
        !!user&.admin? && access(user:, phase: :visibility).allowed
      end

      # Returns why the user can't hand theme work to an app, or nil when
      # they can.
      def self.denial(user:, phase:)
        return I18n.t("discourse_ai.mcp_theme_access.not_allowed") if !user&.admin?

        access = access(user:, phase:)
        if !access.allowed
          return(access.message.presence || I18n.t("discourse_ai.mcp_theme_access.unavailable"))
        end

        # apps would create themes, so a site that can't create them can't use
        # this; the same goes for sites limited to approved theme repositories
        if !user.guardian.can_create_theme? || !Theme.allowed_remote_theme_ids.nil?
          I18n.t("discourse_ai.mcp_theme_access.themes_unavailable")
        end
      end

      def self.access(user:, phase:)
        AdminAssistantAccess.check(feature: FEATURE, user:, phase:)
      end
      private_class_method :access

      def self.server_enabled?
        SiteSetting.public_send(SERVER_SETTING)
      end

      # A global setting fixes the value, so it can't be turned on here.
      def self.server_setting_locked?
        SiteSetting.shadowed_settings.include?(SERVER_SETTING)
      end

      def self.missing_theme_tool_ids
        exposed = McpPrimitive.exposed.pluck(:kind, :identifier).map { |kind, id| "#{kind}:#{id}" }
        THEME_TOOL_IDS - exposed
      end

      def self.blocked_theme_tool_ids
        THEME_TOOL_IDS.select do |primitive_id|
          kind, identifier = primitive_id.split(":", 2)
          McpPrimitive.exists?(kind:, identifier:, emergency_blocked: true)
        end
      end

      # Until access rules are saved for administrators, they get every scope,
      # so that's what they have. Reading this never saves any rules; only an
      # approved enable! does.
      def self.admin_scopes
        McpGroupScope.where(group_id: Group::AUTO_GROUPS[:admins]).pluck(:scope).presence ||
          DiscourseMcp.registry.scopes
      end

      def self.missing_admin_scopes
        THEME_SCOPES - admin_scopes
      end

      # What turning on theme access would change, as Change rows.
      def self.changes
        changes = []
        changes << Change.new(key: :server, before: false, after: true) if !server_enabled?
        missing = missing_theme_tool_ids - blocked_theme_tool_ids
        changes << Change.new(key: :tools, before: [], after: missing) if missing.present?
        scopes = missing_admin_scopes
        changes << Change.new(key: :admin_scopes, before: [], after: scopes) if scopes.present?
        changes
      end

      def self.ready?
        changes.empty? && blocked_theme_tool_ids.empty?
      end

      # Turns on the MCP server, lets apps use the theme tools and gives
      # administrators the theme scopes. Everything else stays as it was. It's
      # all or nothing: if the server can't be turned on, the tools and scopes
      # are left as they were too.
      def self.enable!(guardian:)
        enabled = false

        # approving runs this inside its own transaction, so it needs a
        # savepoint for the rollback to undo anything
        ActiveRecord::Base.transaction(requires_new: true) do
          if (missing = missing_theme_tool_ids - blocked_theme_tool_ids).present?
            # the updater replaces the whole list, so keep what's on
            exposed =
              McpPrimitive.where(enabled: true).pluck(:kind, :identifier).map { |k, i| "#{k}:#{i}" }
            McpPrimitiveUpdater.update!(actor: guardian.user, primitive_ids: exposed + missing)
          end

          if (scopes = missing_admin_scopes).present?
            McpAccessRuleUpdater.replace!(
              actor: guardian.user,
              group_id: Group::AUTO_GROUPS[:admins],
              scopes: admin_scopes + scopes,
            )
          end

          # last, so nothing that can fail follows it before the commit
          raise ActiveRecord::Rollback if !server_enabled? && !enable_server(guardian)

          enabled = true
        end

        enabled
      end

      def self.enable_server(guardian)
        SiteSetting::Update.call(
          guardian:,
          params: {
            settings: [{ setting_name: SERVER_SETTING, value: "true" }],
          },
        ).success?
      end
      private_class_method :enable_server

      # The apps connected to the user's account, and whether each can use
      # the theme tools.
      def self.connections(user)
        McpAppSetup
          .connections(user, scopes: THEME_SCOPES)
          .map do |connection|
            connection.except(:has_scopes).merge(theme_access: connection[:has_scopes])
          end
      end

      # The user's latest calls to the theme tools, from any app.
      def self.recent_theme_calls(user)
        identifiers = THEME_TOOL_IDS.map { |primitive_id| primitive_id.split(":", 2).last }
        McpAuditLog
          .recent_first
          .where(user:, tool: identifiers)
          .includes(:client)
          .limit(RECENT_CALLS)
          .map do |log|
            {
              tool: log.tool,
              app: log.client&.name,
              outcome: log.outcome,
              at: log.occurred_at.iso8601,
            }.compact
          end
      end

      def self.tool_title(primitive_id)
        kind, identifier = primitive_id.split(":", 2)
        DiscourseMcp.registry.find(kind, identifier)&.title || identifier
      end
    end
  end
end
