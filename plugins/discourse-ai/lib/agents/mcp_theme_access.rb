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

      # Apps with setup steps, in the order they're offered.
      APPS = %w[claude chatgpt claude_code codex cursor vscode].freeze
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

      def self.missing_admin_scopes
        McpGroupScope.ensure_admins!
        THEME_SCOPES - McpGroupScope.where(group_id: Group::AUTO_GROUPS[:admins]).pluck(:scope)
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
      # administrators the theme scopes. Everything else stays as it was.
      def self.enable!(guardian:)
        ActiveRecord::Base.transaction do
          if (missing = missing_theme_tool_ids - blocked_theme_tool_ids).present?
            # the updater replaces the whole list, so keep what's on
            enabled =
              McpPrimitive.where(enabled: true).pluck(:kind, :identifier).map { |k, i| "#{k}:#{i}" }
            McpPrimitiveUpdater.update!(actor: guardian.user, primitive_ids: enabled + missing)
          end

          if (scopes = missing_admin_scopes).present?
            current = McpGroupScope.where(group_id: Group::AUTO_GROUPS[:admins]).pluck(:scope)
            McpAccessRuleUpdater.replace!(
              actor: guardian.user,
              group_id: Group::AUTO_GROUPS[:admins],
              scopes: current + scopes,
            )
          end
        end

        # site settings are written after the transaction, the way the admin
        # config writes them
        return true if server_enabled?

        SiteSetting::Update.call(
          guardian:,
          params: {
            settings: [{ setting_name: SERVER_SETTING, value: "true" }],
          },
        ).success?
      end

      # The apps connected to the user's account, whether each can use the
      # theme tools, and whether it has to be approved again first, as
      # happens when new tools become available to it.
      def self.connections(user)
        McpOauthAuthorization
          .where(user:, status: %w[active consent_required], revoked_at: nil)
          .includes(:client, :scope_records)
          .order(consented_at: :desc)
          .map do |authorization|
            {
              app: authorization.client.name,
              theme_access: (THEME_SCOPES - authorization.scopes).empty?,
              needs_approval:
                authorization.status == "consent_required" || !authorization.consent_current?,
              connected_at: authorization.consented_at.iso8601,
            }
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

      # What stops apps from signing in, beyond what turning access on fixes.
      def self.sign_in_notes
        case SiteSetting.mcp_oauth_client_id_metadata_policy
        when "approved_domains"
          domains = SiteSetting.mcp_oauth_client_id_metadata_domains.split("|").compact_blank
          [
            I18n.t(
              "discourse_ai.mcp_theme_access.notes.approved_domains",
              domains: domains.presence&.join(", ") || I18n.t("discourse_ai.mcp_theme_access.none"),
              settings_url: "#{Discourse.base_url}/admin/config/mcp/settings",
            ),
          ]
        when "disabled"
          [
            I18n.t(
              "discourse_ai.mcp_theme_access.notes.pre_registered_only",
              clients_url: "#{Discourse.base_url}/admin/config/mcp/clients",
            ),
          ]
        else
          []
        end
      end

      def self.app_steps(app, site_name:)
        I18n.t(
          "discourse_ai.mcp_theme_access.apps.#{app}.steps",
          url: DiscourseMcp.resource_url,
          name: site_name,
        )
      end

      def self.app_name(app)
        I18n.t("discourse_ai.mcp_theme_access.apps.#{app}.name")
      end

      def self.tool_title(primitive_id)
        kind, identifier = primitive_id.split(":", 2)
        DiscourseMcp.registry.find(kind, identifier)&.title || identifier
      end
    end
  end
end
