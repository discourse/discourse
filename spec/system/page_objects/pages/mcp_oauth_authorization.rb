# frozen_string_literal: true

module PageObjects
  module Pages
    class McpOauthAuthorization < PageObjects::Pages::Base
      def visit(client:, scopes:)
        page.visit(
          "/oauth2/mcp/authorize?#{
            {
              client_id: client.client_id,
              redirect_uri: client.redirect_uris.first,
              response_type: "code",
              code_challenge: "a" * 43,
              code_challenge_method: "S256",
              resource: DiscourseMcp.resource_url,
              scope: scopes.join(" "),
              state: "client-state",
            }.to_query
          }",
        )
        self
      end

      def has_section?(title)
        has_css?(".mcp-consent__section-title", text: title)
      end

      def has_permission?(label)
        has_css?(".authorize-api-key__permissions .mcp-consent__scope", text: label)
      end

      def has_withheld_permission?(label)
        has_css?(".mcp-consent__withheld .mcp-consent__scope", text: label)
      end

      def has_redirect_notice?(text)
        has_css?(".authorize-api-key__redirect-url", text:)
      end

      def show_withheld_permissions
        find(".mcp-consent__withheld summary").click
        self
      end

      def click_authorize
        click_button(I18n.t("mcp.oauth.approve"))
        self
      end

      def click_cancel
        click_button(I18n.t("mcp.oauth.cancel"))
        self
      end
    end
  end
end
