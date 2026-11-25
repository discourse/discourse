# frozen_string_literal: true

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe McpOauthAuthorizationsController, type: :request do
  fab!(:admin)

  let(:pm_scopes) { %w[mcp:private-messages:read mcp:private-messages:write] }
  let(:ordinary_scope) { "mcp:content:read" }
  let(:requested_scopes) { ["mcp:profile:read", ordinary_scope, *pm_scopes] }
  let(:disabled_text) { "Disabled by site policy" }
  let(:client) do
    McpOauthClient.create!(
      client_id: "cr-u6-consent",
      name: "Unit six consent client",
      registration_type: "pre_registered",
      trust_state: "approved",
      redirect_uris: ["http://127.0.0.1/callback"],
    )
  end

  before do
    McpContentRule.delete_all
    SiteSetting.mcp_server_enabled = true
    McpGroupScope.ensure_admins!
    sign_in(admin)
  end

  def consent
    get "/oauth2/mcp/authorize",
        params: {
          client_id: client.client_id,
          redirect_uri: client.redirect_uris.first,
          response_type: "code",
          code_challenge: "a" * 43,
          code_challenge_method: "S256",
          resource: DiscourseMcp.resource_url,
          scope: requested_scopes.join(" "),
        }
    expect(response.status).to eq(200)
    Nokogiri.HTML5(response.body)
  end

  def scope_rows(document, scope)
    document
      .css("code")
      .select { |code| code.text == scope }
      .map { |code| code.ancestors("li").first }
      .compact
  end

  describe "GET /oauth2/mcp/authorize" do
    %w[private_messages u6:orphan u6:unavailable].each do |rule_kind|
      it "[cr-u6] marks every requested PM scope disabled for #{rule_kind} and removes the marks when access returns" do
        if rule_kind == "u6:unavailable"
          registry = DiscourseMcp::Registry.new
          DiscourseMcp::CorePrimitives.register_content_kinds(registry)
          registry.register_tool(
            "u6_consent_scopes",
            title: "Consent scopes",
            description: "Exposes the requested scope vocabulary",
            implementation: ->(**) { raise "Consent must not call a primitive" },
            content: :none,
            required_scopes: requested_scopes,
          )
          registry.register_content_rule_kind(
            rule_kind,
            provider: "u6",
            affected_data_kinds: ["private_messages"],
            config_contract: {
              type: "object",
            },
            compile: ->(_config) { DiscourseMcp::ContentPolicy::Evaluator.new },
            availability: -> { false },
          )
          allow(DiscourseMcp).to receive(:registry).and_return(registry)
        end
        rule = McpContentRule.create!(rule_kind: rule_kind, config: {})
        document = consent
        aggregate_failures do
          pm_scopes.each do |scope|
            rows = scope_rows(document, scope)
            expect(rows).to be_present
            expect(rows.map(&:text).join(" ")).to include(disabled_text)
          end
          expect(scope_rows(document, ordinary_scope).map(&:text).join(" ")).not_to include(
            disabled_text,
          )
        end
        rule.destroy!
        document = consent
        expect(document.text).not_to include(disabled_text)
        expect(document.css(".mcp-consent__granted-scopes code").map(&:text)).to match_array(
          requested_scopes,
        )
        expect(McpOauthAuthorization.where(client: client)).to be_empty
      end
    end

    it "[cr-u6] keeps forum-only and no-row PM scopes unmarked while reflecting a later PM rule" do
      config = {
        allow: {
          mode: "all",
          category_ids: [],
          tag_ids: [],
        },
        deny: {
          category_ids: [],
          tag_ids: [],
        },
      }
      forum = McpContentRule.create!(rule_kind: "forum_content", config: config)
      document = consent
      expect(document.text).not_to include(disabled_text)
      expect(document.css(".mcp-consent__granted-scopes code").map(&:text)).to match_array(
        requested_scopes,
      )
      forum.destroy!
      document = consent
      expect(document.text).not_to include(disabled_text)
      expect(document.css(".mcp-consent__granted-scopes code").map(&:text)).to match_array(
        requested_scopes,
      )
      McpContentRule.create!(rule_kind: "private_messages", config: {})
      document = consent
      pm_scopes.each do |scope|
        expect(scope_rows(document, scope).map(&:text).join(" ")).to include(disabled_text)
      end
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
