# frozen_string_literal: true

require_relative "support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe Admin::McpController, type: :request do
  include_context "with unit six request registry"

  before { sign_in(admin) }

  %w[capabilities access].each do |endpoint|
    describe "GET /admin/mcp/#{endpoint}.json" do
      it "[cr-u6] adds false restricted flags to #{endpoint} with no rows and preserves admin choices" do
        get "/admin/mcp/#{endpoint}.json"
        expect(response.status).to eq(200)
        entries = response.parsed_body.fetch("primitives")
        expect(entries.size).to eq(14)
        entries.each do |entry|
          record =
            McpPrimitive.find_by!(kind: entry.fetch("kind"), identifier: entry.fetch("identifier"))
          expect(entry).to include(
            "restricted" => false,
            "enabled" => record.enabled,
            "emergency_blocked" => record.emergency_blocked,
          )
        end
        expect(response.parsed_body.fetch("initial_scope")).to eq("mcp:profile:read")
        expect(response.parsed_body.fetch("available_scopes")).to eq(["mcp:profile:read"])
        if endpoint == "access"
          expect(response.parsed_body.fetch("private_message_scopes_overridden")).to eq(false)
          expect(
            response
              .parsed_body
              .fetch("access_rules")
              .find { |rule| rule["group_id"] == Group::AUTO_GROUPS[:admins] },
          ).to include("pre_registered" => true)
        end
      end

      it "[cr-u6] reports policy restrictions in #{endpoint} independently of enabled and emergency states" do
        pm = McpContentRule.create!(rule_kind: "private_messages", config: {})
        get "/admin/mcp/#{endpoint}.json"
        expect(response.status).to eq(200)
        blocked = %w[
          u6_pm
          u6_exit
          u6_undeclared
          u6_unbounded
          u6_disabled
          u6_emergency
          u6_unavailable
          u6_resource
          u6_prompt
        ]
        response
          .parsed_body
          .fetch("primitives")
          .each do |entry|
            expect(entry["restricted"]).to eq(blocked.include?(entry.fetch("identifier")))
            expect(entry.fetch("enabled")).to eq(entry.fetch("identifier") != "u6_disabled")
            expect(entry.fetch("available")).to eq(entry.fetch("identifier") != "u6_unavailable")
            expect(entry.fetch("emergency_blocked")).to eq(
              entry.fetch("identifier") == "u6_emergency",
            )
          end
        if endpoint == "access"
          expect(response.parsed_body.fetch("private_message_scopes_overridden")).to eq(true)
        end
        pm.destroy!
        McpContentRule.create!(rule_kind: "forum_content", config: forum_config)
        get "/admin/mcp/#{endpoint}.json"
        expect(response.status).to eq(200)
        blocked << "u6_forum"
        response
          .parsed_body
          .fetch("primitives")
          .each do |entry|
            expect(entry["restricted"]).to eq(blocked.include?(entry.fetch("identifier")))
          end
        if endpoint == "access"
          expect(response.parsed_body.fetch("private_message_scopes_overridden")).to eq(false)
        end
      end

      it "[cr-u6] reports the orphan veto in #{endpoint} while leaving content-free primitives usable" do
        McpContentRule.create!(rule_kind: "u6:orphan", config: {})
        get "/admin/mcp/#{endpoint}.json"
        expect(response.status).to eq(200)
        response
          .parsed_body
          .fetch("primitives")
          .each do |entry|
            expect(entry["restricted"]).to eq(entry.fetch("identifier") != "u6_none")
          end
        if endpoint == "access"
          expect(response.parsed_body.fetch("private_message_scopes_overridden")).to eq(true)
        end
      end
    end
  end

  describe "GET /admin/mcp/overview.json" do
    it "[cr-u6] preserves the no-rule catalog and adds an inactive zero-blocked summary" do
      get "/admin/mcp/overview.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body.fetch("catalog")).to include(
        "tools" => 8,
        "resources" => 2,
        "prompts" => 1,
      )
      expect(response.parsed_body).to include(
        "enabled" => true,
        "status" => "available",
        "content_restrictions" => {
          "active" => false,
          "blocked" => 0,
        },
      )
      expect(response.parsed_body.fetch("metrics")).to include(
        "approved_oauth_clients" => 0,
        "authorizations" => 0,
        "tokens" => 0,
      )
    end

    it "[cr-u6] counts only policy-usable exposed catalog entries and restores them after removal" do
      rule = McpContentRule.create!(rule_kind: "private_messages", config: {})
      get "/admin/mcp/overview.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body.fetch("catalog")).to include(
        "tools" => 4,
        "resources" => 1,
        "prompts" => 0,
      )
      expect(response.parsed_body.fetch("content_restrictions")).to eq(
        "active" => true,
        "blocked" => 6,
      )
      rule.update!(rule_kind: "forum_content", config: forum_config)
      get "/admin/mcp/overview.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body.fetch("catalog")).to include(
        "tools" => 3,
        "resources" => 1,
        "prompts" => 0,
      )
      expect(response.parsed_body.fetch("content_restrictions")).to eq(
        "active" => true,
        "blocked" => 7,
      )
      rule.destroy!
      get "/admin/mcp/overview.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body.fetch("catalog")).to include(
        "tools" => 8,
        "resources" => 2,
        "prompts" => 1,
      )
      expect(response.parsed_body.fetch("content_restrictions")).to eq(
        "active" => false,
        "blocked" => 0,
      )
    end

    it "[cr-u6] counts orphan-blocked exposed entries once even with multiple orphan rows" do
      %w[u6:gone u6:also_gone].each { |name| McpContentRule.create!(rule_kind: name, config: {}) }
      get "/admin/mcp/overview.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body.fetch("catalog")).to include(
        "tools" => 1,
        "resources" => 0,
        "prompts" => 0,
      )
      expect(response.parsed_body.fetch("content_restrictions")).to eq(
        "active" => true,
        "blocked" => 10,
      )
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
