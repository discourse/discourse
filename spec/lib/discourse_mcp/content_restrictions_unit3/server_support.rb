# frozen_string_literal: true

module McpContentRestrictionsUnit3
  module ServerSupport
    def self.included(group)
      group.fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
      group.before do
        SiteSetting.mcp_server_enabled = true
        SiteSetting.tagging_enabled = true
      end
      group.let(:access_token) do
        client =
          McpOauthClient.create!(
            client_id: SecureRandom.hex,
            name: "Unit 3 regression administrator",
            registration_type: "pre_registered",
            trust_state: "approved",
            redirect_uris: ["http://127.0.0.1/callback"],
          )
        authorization =
          DiscourseMcp::OAuth::AuthorizationGrant.create!(
            user: admin,
            client:,
            redirect_uri: client.redirect_uris.first,
            requested_scopes: DiscourseMcp.registry.scopes,
          )
        raw = McpOauthAccessToken.issue!(authorization:)
        McpOauthAccessToken.find_by!(token_hash: McpOauthAccessToken.digest(raw))
      end
    end

    def rpc(name, arguments)
      primitive = DiscourseMcp.registry.find(:tool, name)
      expect(primitive).to be_present
      expect(JSONSchemer.schema(primitive.input_schema).validate(arguments).to_a).to eq([])
      McpPrimitive.find_or_create_by!(kind: "tool", identifier: name).update!(enabled: true)
      request = ActionDispatch::TestRequest.create
      request.headers["MCP-Protocol-Version"] = DiscourseMcp::LEGACY_PROTOCOL_VERSION
      response =
        DiscourseMcp::Server.new(
          request:,
          request_context: DiscourseMcp::RequestContext.new(access_token),
        ).call(
          {
            "jsonrpc" => "2.0",
            "id" => 1,
            "method" => "tools/call",
            "params" => {
              "name" => name,
              "arguments" => arguments,
            },
          },
        )
      JSON.parse(
        JSON.generate(status: response.http_status, headers: response.headers, body: response.body),
      )
    end

    def expect_usable(response)
      expect(response.fetch("status")).to eq(200), response.inspect
      expect(response.dig("body", "error")).to be_nil, response.inspect
      expect(response.dig("body", "result", "isError")).not_to eq(true), response.inspect
      expect(response.dig("body", "result", "structuredContent")).to be_present
    end

    def payloads(response)
      result = response.fetch("body").fetch("result")
      [result.fetch("structuredContent")] +
        result
          .fetch("content")
          .filter_map { |part| JSON.parse(part.fetch("text")) if part["type"] == "text" }
    end

    def expect_absent(value, forbidden, label)
      serialized = JSON.generate(value)
      forbidden.uniq.each do |token|
        pattern =
          if token.is_a?(Integer)
            /(?<!\d)#{token}(?!\d)/
          else
            /#{Regexp.escape(token.to_s)}/i
          end
        expect(serialized).not_to match(pattern),
        "#{label}: restricted token #{token.inspect} in #{serialized}"
      end
    end

    def forum_rule(denied_categories: [], denied_tags: [], selected_tags: nil)
      McpContentRule.create!(
        rule_kind: "forum_content",
        config: {
          allow: {
            mode: selected_tags ? "selected" : "all",
            category_ids: [],
            tag_ids: selected_tags || [],
          },
          deny: {
            category_ids: denied_categories,
            tag_ids: denied_tags,
          },
        },
      )
    end

    def group_call(tool, group)
      arguments =
        if tool == "discourse_get_group"
          { "id" => group.id }
        else
          { "group_id" => group.id, "full_name" => "Reviewable group" }
        end
      rpc(tool, arguments).tap { |response| expect_usable(response) }
    end
  end
end
