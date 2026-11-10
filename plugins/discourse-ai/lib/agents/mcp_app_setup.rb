# frozen_string_literal: true

module DiscourseAi
  module Agents
    # How an administrator connects their own AI app to the site's MCP server,
    # whatever they'll use it for: each app's setup steps, what stops apps
    # from signing in, and which apps are connected. Tools that hand work to
    # an app build on it.
    module McpAppSetup
      # Apps with setup steps, in the order they're offered.
      APPS = %w[claude chatgpt claude_code codex cursor vscode].freeze

      def self.app_name(app)
        I18n.t("discourse_ai.mcp_app_setup.apps.#{app}.name")
      end

      def self.app_steps(app, site_name:)
        I18n.t(
          "discourse_ai.mcp_app_setup.apps.#{app}.steps",
          url: DiscourseMcp.resource_url,
          name: site_name,
        )
      end

      # What stops apps from signing in, beyond what turning access on fixes.
      def self.sign_in_notes
        case SiteSetting.mcp_oauth_client_id_metadata_policy
        when "approved_domains"
          domains = SiteSetting.mcp_oauth_client_id_metadata_domains.split("|").compact_blank
          [
            I18n.t(
              "discourse_ai.mcp_app_setup.notes.approved_domains",
              domains: domains.presence&.join(", ") || I18n.t("discourse_ai.mcp_app_setup.none"),
              settings_url: "#{Discourse.base_url}/admin/config/mcp/settings",
            ),
          ]
        when "disabled"
          [
            I18n.t(
              "discourse_ai.mcp_app_setup.notes.pre_registered_only",
              clients_url: "#{Discourse.base_url}/admin/config/mcp/clients",
            ),
          ]
        else
          []
        end
      end

      # The apps connected to the user's account, whether each has the given
      # scopes, and whether it has to be approved again first, as happens
      # when new tools become available to it.
      def self.connections(user, scopes:)
        McpOauthAuthorization
          .where(user:, status: %w[active consent_required], revoked_at: nil)
          .includes(:client, :scope_records)
          .order(consented_at: :desc)
          .map do |authorization|
            {
              app: authorization.client.name,
              has_scopes: (scopes - authorization.scopes).empty?,
              needs_approval:
                authorization.status == "consent_required" || !authorization.consent_current?,
              connected_at: authorization.consented_at.iso8601,
            }
          end
      end
    end
  end
end
