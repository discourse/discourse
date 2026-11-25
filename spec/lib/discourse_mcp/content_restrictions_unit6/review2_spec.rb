# frozen_string_literal: true

require_relative "support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe Admin::McpController, type: :request, aggregate_failures: true do
  include_context "with unit six request registry"

  before { sign_in(admin) }

  describe "#update_content_restriction" do
    %w[allow deny].each do |side|
      it "[cr-u6] applies #{side} synonym names to topics carrying the canonical tag" do
        canonical = Fabricate(:tag, id: 114_620_001, name: "u6r2-canonical")
        synonym = Fabricate(:tag, id: 114_620_002, name: "u6r2-synonym", target_tag: canonical)
        tagged = Fabricate(:topic, id: 114_620_003, tags: [canonical])
        other = Fabricate(:topic, id: 114_620_004)
        config = forum_config
        config["allow"]["mode"] = "selected" if side == "allow"
        config[side].delete("tag_ids")
        config[side]["tag_names"] = [synonym.name.upcase]

        put "/admin/mcp/content-restrictions/forum_content.json", params: { config: }, as: :json

        expect(response.status).to eq(200)
        expect(McpContentRule.find_by!(rule_kind: "forum_content")).to be_persisted
        visible =
          DiscourseMcp::ContentPolicy.load.scope_topics(Topic.where(id: [tagged.id, other.id]))
        expect(visible.pluck(:id)).to eq([side == "allow" ? tagged.id : other.id])
      end

      {
        "null" => nil,
        "scalar" => "u6r2-valid",
        "object" => {
        },
        "mixed names and ids" => ["u6r2-valid"],
      }.each do |shape, names|
        it "[cr-u6] refuses #{side} #{shape} tag input on create and replace without storage or logs" do
          tag = Fabricate(:tag, id: 114_620_011, name: "u6r2-valid")
          different = Fabricate(:tag, id: 114_620_012, name: "u6r2-different")
          bad = forum_config
          bad[side].delete("tag_ids")
          bad[side]["tag_names"] = names
          bad[side]["tag_ids"] = [different.id] if shape == "mixed names and ids"
          previous = forum_config
          previous["deny"]["tag_ids"] = [tag.id]

          [false, true].each do |replacing|
            McpContentRule.delete_all
            existing =
              if replacing
                McpContentRule.create!(
                  rule_kind: "forum_content",
                  config: previous,
                  updated_by: admin,
                )
              end
            before_rows = McpContentRule.order(:id).map(&:attributes)
            before_logs =
              UserHistory.where(
                custom_type: %w[mcp_content_rule_updated mcp_content_rule_deleted],
              ).pluck(:id)

            put "/admin/mcp/content-restrictions/forum_content.json",
                params: {
                  config: bad,
                },
                as: :json

            aggregate_failures("#{replacing ? "replace" : "create"} refusal") do
              expect(response.status).to eq(400)
              expect(response.parsed_body["errors"]).to be_present
              expect(McpContentRule.order(:id).map(&:attributes)).to eq(before_rows)
              expect(
                UserHistory.where(
                  custom_type: %w[mcp_content_rule_updated mcp_content_rule_deleted],
                ).pluck(:id),
              ).to eq(before_logs)
              expect(existing.reload.config).to eq(previous) if existing
            end
          end
        end
      end
    end

    it "[cr-u6] controls valid names empty arrays numeric ids and unknown or non-string scalar names" do
      tag = Fabricate(:tag, id: 114_620_021, name: "u6r2-control")
      %w[allow deny].each do |side|
        [[tag.name.upcase, tag.name], []].each do |names|
          config = forum_config
          config[side].delete("tag_ids")
          config[side]["tag_names"] = names
          put "/admin/mcp/content-restrictions/forum_content.json", params: { config: }, as: :json
          expect(response.status).to eq(200)
          expected = forum_config
          expected[side]["tag_ids"] = names.empty? ? [] : [tag.id]
          expect(McpContentRule.find_by!(rule_kind: "forum_content").config).to eq(expected)
        end
      end
      config = forum_config
      config["allow"]["tag_ids"] = [tag.id]
      put "/admin/mcp/content-restrictions/forum_content.json", params: { config: }, as: :json
      expect(response.status).to eq(200)
      expect(McpContentRule.find_by!(rule_kind: "forum_content").config).to eq(config)

      %w[allow deny].each do |side|
        [[tag.name, "u6r2-unknown"], { "name" => tag.name }, 123, false].each do |names|
          bad = forum_config
          bad[side].delete("tag_ids")
          bad[side]["tag_names"] = names
          before_rows = McpContentRule.order(:id).map(&:attributes)
          before_logs = UserHistory.where(custom_type: "mcp_content_rule_updated").pluck(:id)
          put "/admin/mcp/content-restrictions/forum_content.json",
              params: {
                config: bad,
              },
              as: :json
          aggregate_failures do
            expect(response.status).to eq(400)
            expect(response.parsed_body["errors"]).to be_present
            expect(McpContentRule.order(:id).map(&:attributes)).to eq(before_rows)
            expect(UserHistory.where(custom_type: "mcp_content_rule_updated").pluck(:id)).to eq(
              before_logs,
            )
            expect(Tag.exists?(name: "u6r2-unknown")).to eq(false)
          end
        end
      end
    end

    it "[cr-u6] logs a new forum rule's normalized stored config" do
      tag = Fabricate(:tag, id: 114_620_031, name: "u6r2-log-create")
      config = forum_config
      config["deny"].delete("tag_ids")
      config["deny"]["tag_names"] = [tag.name]

      put "/admin/mcp/content-restrictions/forum_content.json", params: { config: }, as: :json

      expect(response.status).to eq(200)
      expected = forum_config
      expected["deny"]["tag_ids"] = [tag.id]
      expect(McpContentRule.find_by!(rule_kind: "forum_content").config).to eq(expected)
      log = history("mcp_content_rule_updated")
      expect(log.acting_user_id).to eq(admin.id)
      expect(log.details).to include("forum_content")
      aggregate_failures do
        expect(log.previous_value).to be_nil
        expect(JSON.parse(log.new_value.presence || "null")).to eq(expected)
      end
    end

    it "[cr-u6] logs previous and new stored configs when a forum rule is relaxed" do
      allowed = Fabricate(:tag, id: 114_620_032, name: "u6r2-log-allowed")
      denied = Fabricate(:tag, id: 114_620_033, name: "u6r2-log-denied")
      retained = Fabricate(:tag, id: 114_620_034, name: "u6r2-log-retained")
      allowed_category = Fabricate(:category, id: 114_620_041)
      denied_category = Fabricate(:category, id: 114_620_042)
      previous = forum_config
      previous["allow"].merge!(
        "mode" => "selected",
        "category_ids" => [allowed_category.id],
        "tag_ids" => [allowed.id],
      )
      previous["deny"].merge!(
        "category_ids" => [denied_category.id],
        "tag_ids" => [denied.id, retained.id],
      )
      put "/admin/mcp/content-restrictions/forum_content.json",
          params: {
            config: previous,
          },
          as: :json
      expect(response.status).to eq(200)
      row = McpContentRule.find_by!(rule_kind: "forum_content")
      expect(row.config).to eq(previous)
      config = forum_config
      config["deny"].delete("tag_ids")
      config["deny"]["tag_names"] = [retained.name]
      expected = forum_config
      expected["deny"]["tag_ids"] = [retained.id]
      before_logs = UserHistory.where(custom_type: "mcp_content_rule_updated").count

      put "/admin/mcp/content-restrictions/forum_content.json", params: { config: }, as: :json

      expect(response.status).to eq(200)
      expect(row.reload.config).to eq(expected)
      expect(UserHistory.where(custom_type: "mcp_content_rule_updated").count).to eq(
        before_logs + 1,
      )
      log = history("mcp_content_rule_updated")
      expect(log.acting_user_id).to eq(admin.id)
      expect(log.details).to include("forum_content")
      aggregate_failures do
        expect(JSON.parse(log.previous_value.presence || "null")).to eq(previous)
        expect(JSON.parse(log.new_value.presence || "null")).to eq(expected)
        expect(
          log.details.scan(/(?:tool|resource_template|resource|prompt):[A-Za-z0-9_.-]+/),
        ).to eq([])
      end
    end
  end

  describe "#destroy_content_restriction" do
    it "[cr-u6] logs the removed stored config when a forum rule is deleted" do
      tag = Fabricate(:tag, id: 114_620_035, name: "u6r2-log-delete")
      category = Fabricate(:category, id: 114_620_043)
      config = forum_config
      config["allow"].merge!("mode" => "selected", "category_ids" => [category.id])
      config["deny"].delete("tag_ids")
      config["deny"]["tag_names"] = [tag.name]
      put "/admin/mcp/content-restrictions/forum_content.json", params: { config: }, as: :json
      expect(response.status).to eq(200)
      row = McpContentRule.find_by!(rule_kind: "forum_content")
      removed = row.config.deep_dup
      expect(removed.dig("deny", "tag_ids")).to eq([tag.id])

      delete "/admin/mcp/content-restrictions/forum_content.json"

      expect(response.status).to eq(204)
      expect(McpContentRule.exists?(row.id)).to eq(false)
      expect(UserHistory.where(custom_type: "mcp_content_rule_deleted").count).to eq(1)
      log = history("mcp_content_rule_deleted")
      expect(log.acting_user_id).to eq(admin.id)
      expect(log.details).to include("forum_content")
      expect(JSON.parse(log.previous_value.presence || "null")).to eq(removed)
    end
  end

  describe "revoked scope impact across admin requests" do
    let(:scoped_ids) do
      %w[
        tool:u6r2_none_read
        tool:u6r2_filtered_write
        resource:u6r2_untouched_read
        resource_template:u6r2_none_write
        prompt:u6r2_multi
      ]
    end
    let(:pm_disabled) do
      %w[
        tool:u6_pm
        tool:u6_exit
        tool:u6_undeclared
        tool:u6_unbounded
        resource:u6_resource
        prompt:u6_prompt
      ] + scoped_ids
    end
    let(:orphan_disabled) do
      %w[
        tool:u6_untouched
        tool:u6_filtered
        tool:u6_forum
        tool:u6_pm
        tool:u6_exit
        tool:u6_undeclared
        tool:u6_unbounded
        resource:u6_resource
        resource_template:u6_template
        prompt:u6_prompt
      ] + scoped_ids
    end

    before do
      [
        ["u6r2_none_read", :tool, :none, ["mcp:private-messages:read"], true, false, true],
        ["u6r2_filtered_write", :tool, filtered, ["mcp:private-messages:write"], true, false, true],
        [
          "u6r2_untouched_read",
          :resource,
          untouched,
          ["mcp:private-messages:read"],
          true,
          false,
          true,
        ],
        [
          "u6r2_none_write",
          :resource_template,
          :none,
          ["mcp:private-messages:write"],
          true,
          false,
          true,
        ],
        [
          "u6r2_multi",
          :prompt,
          filtered,
          %w[mcp:profile:read mcp:private-messages:read],
          true,
          false,
          true,
        ],
        ["u6r2_disabled", :tool, untouched, ["mcp:private-messages:write"], false, false, true],
        ["u6r2_emergency", :tool, :none, ["mcp:private-messages:read"], true, true, true],
        ["u6r2_unavailable", :tool, filtered, ["mcp:private-messages:write"], true, false, false],
      ].each do |identifier, kind, content, scopes, enabled, blocked, available|
        registry.register(
          identifier:,
          kind:,
          title: identifier,
          description: "Review two scope oracle",
          implementation: ->(**) { raise "Request oracle must not invoke primitives" },
          content:,
          required_scopes: scopes,
          availability: -> { available },
        )
        McpPrimitive.create!(identifier:, kind:, enabled:, emergency_blocked: blocked)
      end
      register_rule("u6:review2_offline", availability: -> { false })
    end

    %w[private_messages u6:review2_offline].each do |rule_kind|
      it "[cr-u6] reports revoked-scope primitives as disabled rather than restricted for #{rule_kind}" do
        expected = rule_kind == "private_messages" ? pm_disabled : orphan_disabled
        content_get
        aggregate_failures("inactive preview") do
          expect(rule_entry(rule_kind).fetch("disables")).to match_array(expected)
          expect(rule_entry(rule_kind).fetch("newly_disables")).to match_array(expected)
          expect(rule_entry(rule_kind).fetch("restricts")).to match_array(
            (
              if rule_kind == "private_messages"
                %w[tool:u6_filtered resource_template:u6_template]
              else
                []
              end
            ),
          )
        end
        if rule_kind == "private_messages"
          put "/admin/mcp/content-restrictions/private_messages.json",
              params: {
                config: {
                },
              },
              as: :json
          expect(response.status).to eq(200)
        else
          McpContentRule.create!(rule_kind:, config: {})
        end
        content_get
        aggregate_failures("active entry") do
          expect(rule_entry(rule_kind).fetch("disables")).to match_array(expected)
          expect(rule_entry(rule_kind).fetch("newly_disables")).to eq([])
          expect(rule_entry(rule_kind).fetch("restricts")).to match_array(
            (
              if rule_kind == "private_messages"
                %w[tool:u6_filtered resource_template:u6_template]
              else
                []
              end
            ),
          )
        end
      end

      %w[capabilities access].each do |endpoint|
        it "[cr-u6] marks revoked-scope primitives restricted in #{endpoint} under #{rule_kind}" do
          McpContentRule.create!(rule_kind:, config: {})
          get "/admin/mcp/#{endpoint}.json"
          expect(response.status).to eq(200)
          entries = response.parsed_body.fetch("primitives")
          scoped = entries.select { |entry| entry.fetch("identifier").start_with?("u6r2_") }
          aggregate_failures do
            expect(scoped.size).to eq(8)
            scoped.each do |entry|
              expect(entry.fetch("restricted")).to eq(true), entry.fetch("id")
              record = McpPrimitive.find_by!(identifier: entry.fetch("identifier"))
              expect(entry).to include(
                "enabled" => record.enabled,
                "emergency_blocked" => record.emergency_blocked,
                "available" => (record.identifier != "u6r2_unavailable"),
              )
            end
            expect(
              entries.find { |entry| entry.fetch("identifier") == "u6_none" }.fetch("restricted"),
            ).to eq(false)
          end
        end
      end

      it "[cr-u6] counts revoked-scope primitives as blocked and removes them from the #{rule_kind} catalog" do
        McpContentRule.create!(rule_kind:, config: {})
        get "/admin/mcp/overview.json"
        expect(response.status).to eq(200)
        aggregate_failures do
          expect(response.parsed_body.fetch("content_restrictions")).to eq(
            "active" => true,
            "blocked" => (rule_kind == "private_messages" ? 11 : 15),
          )
          expect(response.parsed_body.fetch("catalog")).to include(
            "tools" => (rule_kind == "private_messages" ? 4 : 1),
            "resources" => (rule_kind == "private_messages" ? 1 : 0),
            "prompts" => 0,
          )
        end
      end
    end

    it "[cr-u6] logs exactly newly disabled ids including revoked scopes and respects an existing orphan" do
      put "/admin/mcp/content-restrictions/private_messages.json", params: { config: {} }, as: :json
      expect(response.status).to eq(200)
      aggregate_failures("new PM rule") do
        expect(
          history("mcp_content_rule_updated").details.scan(
            /(?:tool|resource_template|resource|prompt):[A-Za-z0-9_.-]+/,
          ),
        ).to match_array(pm_disabled)
      end
      delete "/admin/mcp/content-restrictions/private_messages.json"
      expect(response.status).to eq(204)
      McpContentRule.create!(rule_kind: "u6:review2_offline", config: {})
      put "/admin/mcp/content-restrictions/private_messages.json", params: { config: {} }, as: :json
      expect(response.status).to eq(200)
      expect(
        history("mcp_content_rule_updated").details.scan(
          /(?:tool|resource_template|resource|prompt):[A-Za-z0-9_.-]+/,
        ),
      ).to eq([])
    end

    it "[cr-u6] controls scoped primitives with no rule a forum-only rule and after PM removal" do
      [nil, "forum_content", "private_messages"].each do |rule_kind|
        if rule_kind
          put "/admin/mcp/content-restrictions/#{rule_kind}.json",
              params: {
                config: rule_kind == "forum_content" ? forum_config : {},
              },
              as: :json
          expect(response.status).to eq(200)
          if rule_kind == "private_messages"
            delete "/admin/mcp/content-restrictions/private_messages.json"
            expect(response.status).to eq(204)
          end
        end
        %w[capabilities access].each do |endpoint|
          get "/admin/mcp/#{endpoint}.json"
          expect(response.status).to eq(200)
          entries =
            response
              .parsed_body
              .fetch("primitives")
              .select { |entry| entry.fetch("identifier").start_with?("u6r2_") }
          expect(entries.size).to eq(8)
          expect(entries.pluck("restricted")).to eq([false] * 8)
        end
        get "/admin/mcp/overview.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body.fetch("catalog")).to include(
          "tools" => (rule_kind ? 5 : 10),
          "resources" => (rule_kind ? 3 : 4),
          "prompts" => (rule_kind ? 1 : 2),
        )
        expect(response.parsed_body.fetch("content_restrictions")).to eq(
          "active" => !!rule_kind,
          "blocked" => (rule_kind ? 7 : 0),
        )
      end
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
