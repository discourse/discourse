# frozen_string_literal: true

require_relative "support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe Admin::McpController, type: :request do
  include_context "with unit six request registry"

  before { sign_in(admin) }

  describe "GET /admin/mcp/content-restrictions.json" do
    it "[cr-u6] lists registered kinds in registration order with string component ids and inactive metadata" do
      register_rule("u6:zeta", admin_component_id: "u6-editor")
      register_rule("u6:alpha")
      register_rule("u6:offline", availability: -> { false })

      content_get

      entries = response.parsed_body.fetch("rule_kinds")
      expect(entries.pluck("name")).to eq(
        %w[private_messages forum_content u6:zeta u6:alpha u6:offline],
      )
      expect(entries.pluck("provider")).to eq(%w[core core u6 u6 u6])
      expect(entries.first(3).pluck("admin_component_id")).to eq(
        %w[private_messages forum_content u6-editor],
      )
      expect(entries.last(2).pluck("admin_component_id")).to all(be_a(String))
      entries.each do |entry|
        expect(entry).to include(
          "active" => false,
          "config" => nil,
          "updated_at" => nil,
          "updated_by" => nil,
        )
      end
      expect(response.parsed_body).to include(
        "orphans" => [],
        "private_message_scopes_overridden" => false,
      )
      expect(rule_entry("forum_content").fetch("references")).to eq(
        "categories" => [],
        "tags" => [],
        "missing_category_ids" => [],
        "missing_tag_ids" => [],
      )
    end

    it "[cr-u6] reports active stored config timestamp and updater including a null updater" do
      rule =
        McpContentRule.create!(rule_kind: "forum_content", config: forum_config, updated_by: admin)
      pm = McpContentRule.create!(rule_kind: "private_messages", config: {})

      content_get

      expect(rule_entry("forum_content")).to include(
        "active" => true,
        "config" => forum_config,
        "updated_by" => admin.username,
        "newly_disables" => [],
      )
      expect(Time.zone.parse(rule_entry("forum_content").fetch("updated_at"))).to be_within(
        1.second,
      ).of(rule.updated_at)
      expect(rule_entry("private_messages")).to include(
        "active" => true,
        "config" => {
        },
        "updated_by" => nil,
        "newly_disables" => [],
      )
      expect(Time.zone.parse(rule_entry("private_messages").fetch("updated_at"))).to be_within(
        1.second,
      ).of(pm.updated_at)
      expect(response.parsed_body.fetch("private_message_scopes_overridden")).to eq(true)
    end

    it "[cr-u6] resolves both reference sides and reports missing ids once without expanding subtrees" do
      allow_category = Fabricate(:category, id: 114_600_001)
      deny_category = Fabricate(:category, id: 114_600_002)
      Fabricate(:category, id: 114_600_003, parent_category: deny_category)
      allow_tag = Fabricate(:tag, id: 114_600_011, name: "u6-allowed")
      deny_tag = Fabricate(:tag, id: 114_600_012, name: "u6-denied")
      config = forum_config
      config["allow"].merge!(
        "mode" => "selected",
        "category_ids" => [allow_category.id, 114_600_091],
        "tag_ids" => [allow_tag.id, 114_600_092],
      )
      config["deny"].merge!(
        "category_ids" => [deny_category.id, allow_category.id, 114_600_091],
        "tag_ids" => [deny_tag.id, allow_tag.id, 114_600_092],
      )
      row = McpContentRule.create!(rule_kind: "forum_content", config: forum_config)
      row.update_columns(config: config)

      content_get

      references = rule_entry("forum_content").fetch("references")
      expect(references.fetch("categories")).to contain_exactly(
        { "id" => allow_category.id, "name" => allow_category.name },
        { "id" => deny_category.id, "name" => deny_category.name },
      )
      expect(references.fetch("tags")).to contain_exactly(
        { "id" => allow_tag.id, "name" => allow_tag.name },
        { "id" => deny_tag.id, "name" => deny_tag.name },
      )
      expect(references.fetch("missing_category_ids")).to eq([114_600_091])
      expect(references.fetch("missing_tag_ids")).to eq([114_600_092])
      expect(rule_entry("forum_content").fetch("config")).to eq(config)
    end

    it "[cr-u6] computes independent impact from declarations across primitive kinds and exposure states" do
      register_rule("u6:topics", admin_component_id: "topics-editor")
      common = %w[
        tool:u6_exit
        tool:u6_undeclared
        tool:u6_unbounded
        resource:u6_resource
        prompt:u6_prompt
      ]

      content_get

      expected = {
        "private_messages" => common + ["tool:u6_pm"],
        "forum_content" => common + %w[tool:u6_pm tool:u6_forum],
        "u6:topics" => common + ["tool:u6_forum"],
      }
      expected.each do |name, disabled|
        expect(rule_entry(name).fetch("disables")).to match_array(disabled)
        expect(rule_entry(name).fetch("newly_disables")).to match_array(disabled)
        expect(rule_entry(name).fetch("restricts")).to match_array(
          %w[tool:u6_filtered resource_template:u6_template],
        )
      end
    end

    it "[cr-u6] computes marginal impact against active rules and the orphan veto" do
      McpContentRule.create!(rule_kind: "private_messages", config: {})

      content_get

      expect(rule_entry("private_messages").fetch("newly_disables")).to eq([])
      expect(rule_entry("forum_content").fetch("newly_disables")).to eq(["tool:u6_forum"])
      orphan = McpContentRule.create!(rule_kind: "u6:gone", config: {})
      content_get
      expect(rule_entry("forum_content").fetch("newly_disables")).to eq([])
      expect(rule_entry("forum_content").fetch("disables")).to include("tool:u6_forum")
      expect(orphan).to be_persisted
    end

    it "[cr-u6] lists unregistered and unavailable orphans and restores the PM override on removal" do
      register_rule("u6:offline", availability: -> { false })
      rows =
        %w[u6:gone u6:offline].map { |name| McpContentRule.create!(rule_kind: name, config: {}) }

      content_get

      expect(response.parsed_body.fetch("orphans").pluck("rule_kind")).to match_array(
        rows.map(&:rule_kind),
      )
      response
        .parsed_body
        .fetch("orphans")
        .each do |entry|
          row = rows.find { |candidate| candidate.rule_kind == entry.fetch("rule_kind") }
          expect(Time.zone.parse(entry.fetch("updated_at"))).to be_within(1.second).of(
            row.updated_at,
          )
        end
      expect(rule_entry("u6:offline")).to include("active" => true, "config" => {})
      expect(response.parsed_body.fetch("private_message_scopes_overridden")).to eq(true)
      rows.each(&:destroy!)
      content_get
      expect(response.parsed_body).to include(
        "orphans" => [],
        "private_message_scopes_overridden" => false,
      )
    end
  end

  describe "PUT /admin/mcp/content-restrictions/:rule_kind.json" do
    it "[cr-u6] creates and replaces one row with the actor and returns the full GET payload" do
      other_admin = Fabricate(:admin)
      existing =
        McpContentRule.create!(
          rule_kind: "private_messages",
          config: {
          },
          updated_by: other_admin,
          updated_at: 1.day.ago,
        )
      original_time = existing.updated_at

      put "/admin/mcp/content-restrictions/private_messages.json", params: { config: {} }, as: :json

      expect(response.status).to eq(200)
      expect(existing.reload.updated_by_id).to eq(admin.id)
      expect(existing.updated_at).to be > original_time
      expect(McpContentRule.where(rule_kind: "private_messages").pluck(:id)).to eq([existing.id])
      replaced_payload = response.parsed_body
      content_get
      expect(response.parsed_body).to eq(replaced_payload)
      delete "/admin/mcp/content-restrictions/private_messages.json"
      put "/admin/mcp/content-restrictions/private_messages.json", params: { config: {} }, as: :json
      expect(response.status).to eq(200)
      created = McpContentRule.find_by!(rule_kind: "private_messages")
      expect(created.updated_by_id).to eq(admin.id)
      expect(created.config).to eq({})
      created_payload = response.parsed_body
      content_get
      expect(response.parsed_body).to eq(created_payload)
    end

    it "[cr-u6] resolves tag names on both sides and replaces the entire forum config" do
      allowed = Fabricate(:tag, id: 114_600_021, name: "u6-allow-save")
      denied = Fabricate(:tag, id: 114_600_022, name: "u6-deny-save")
      category = Fabricate(:category, id: 114_600_023)
      config = forum_config
      config["allow"].merge!("mode" => "selected", "category_ids" => [category.id])
      config["allow"].delete("tag_ids")
      config["deny"].delete("tag_ids")
      config["allow"]["tag_names"] = [allowed.name]
      config["deny"]["tag_names"] = [denied.name]

      put "/admin/mcp/content-restrictions/forum_content.json",
          params: {
            config: config,
          },
          as: :json

      expect(response.status).to eq(200)
      expected = forum_config
      expected["allow"].merge!(
        "mode" => "selected",
        "category_ids" => [category.id],
        "tag_ids" => [allowed.id],
      )
      expected["deny"]["tag_ids"] = [denied.id]
      row = McpContentRule.find_by!(rule_kind: "forum_content")
      expect(row.config).to eq(expected)
      expect(row.updated_by_id).to eq(admin.id)
      expect(rule_entry("forum_content").fetch("config")).to eq(expected)
      put "/admin/mcp/content-restrictions/forum_content.json",
          params: {
            config: forum_config,
          },
          as: :json
      expect(response.status).to eq(200)
      expect(row.reload.config).to eq(forum_config)
      payload = response.parsed_body
      content_get
      expect(response.parsed_body).to eq(payload)
    end

    it "[cr-u6] validates a registered provider contract rather than hardcoding core kinds" do
      register_rule(
        "u6:custom",
        config_contract: {
          type: "object",
          required: ["choice"],
          properties: {
            choice: {
              const: "narrow",
            },
          },
          additionalProperties: false,
        },
      )
      put "/admin/mcp/content-restrictions/u6:custom.json",
          params: {
            config: {
              choice: "narrow",
            },
          },
          as: :json
      expect(response.status).to eq(200)
      expect(McpContentRule.find_by!(rule_kind: "u6:custom").config).to eq("choice" => "narrow")
      put "/admin/mcp/content-restrictions/u6:custom.json",
          params: {
            config: {
              choice: "wide",
            },
          },
          as: :json
      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"]).to be_present
      expect(McpContentRule.find_by!(rule_kind: "u6:custom").config).to eq("choice" => "narrow")
    end

    %w[unknown_tag invalid_contract missing_category].each do |failure|
      it "[cr-u6] refuses #{failure} without storing a new row or replacing an existing config" do
        if failure == "missing_category"
          put "/admin/mcp/content-restrictions/forum_content.json",
              params: {
                config: forum_config,
              },
              as: :json
          expect(response.status).to eq(200)
          McpContentRule.find_by!(rule_kind: "forum_content").destroy!
        end
        bad = forum_config
        if failure == "unknown_tag"
          bad["deny"].delete("tag_ids")
          bad["deny"]["tag_names"] = ["u6-does-not-exist"]
        elsif failure == "invalid_contract"
          bad["allow"]["mode"] = "everything"
        else
          bad["deny"]["category_ids"] = [114_600_099]
        end
        [
          nil,
          McpContentRule.new(rule_kind: "forum_content", config: forum_config),
        ].each do |existing|
          existing&.save!
          previous_attributes = existing&.reload&.attributes
          before_history = UserHistory.where(custom_type: "mcp_content_rule_updated").count
          put "/admin/mcp/content-restrictions/forum_content.json",
              params: {
                config: bad,
              },
              as: :json
          aggregate_failures do
            expect(response.status).to(
              failure == "missing_category" ? be_between(400, 499) : eq(400),
            )
            expect(response.parsed_body["errors"]).to be_present
            expect(McpContentRule.find_by(rule_kind: "forum_content")&.attributes).to eq(
              previous_attributes,
            )
            expect(UserHistory.where(custom_type: "mcp_content_rule_updated").count).to eq(
              before_history,
            )
            expect(Tag.exists?(name: "u6-does-not-exist")).to eq(false)
          end
        end
      end
    end

    it "[cr-u6] refuses writes to unregistered and unavailable kinds with 404" do
      register_rule("u6:offline", availability: -> { false })
      McpContentRule.create!(rule_kind: "u6:offline", config: {})
      content_get
      %w[u6:unknown u6:offline].each do |name|
        put "/admin/mcp/content-restrictions/#{name}.json",
            params: {
              config: {
                changed: true,
              },
            },
            as: :json
        expect(response.status).to eq(404)
      end
      expect(McpContentRule.find_by(rule_kind: "u6:unknown")).to be_nil
      expect(McpContentRule.find_by!(rule_kind: "u6:offline").config).to eq({})
    end

    it "[cr-u6] logs the rule and exactly the newly disabled primitive ids" do
      McpContentRule.create!(rule_kind: "private_messages", config: {})
      put "/admin/mcp/content-restrictions/forum_content.json",
          params: {
            config: forum_config,
          },
          as: :json
      expect(response.status).to eq(200)
      log = history("mcp_content_rule_updated")
      expect(log).to be_present
      expect(log.acting_user_id).to eq(admin.id)
      expect(log.action).to eq(UserHistory.actions[:custom_staff])
      expect(log.details).to include("forum_content", "tool:u6_forum")
      logged_ids = log.details.scan(/(?:tool|resource_template|resource|prompt):[A-Za-z0-9_.-]+/)
      expect(logged_ids).to eq(["tool:u6_forum"])
      put "/admin/mcp/content-restrictions/forum_content.json",
          params: {
            config: forum_config,
          },
          as: :json
      expect(response.status).to eq(200)
      expect(
        history("mcp_content_rule_updated").details.scan(
          /(?:tool|resource_template|resource|prompt):[A-Za-z0-9_.-]+/,
        ),
      ).to eq([])
      expect(UserHistory.where(custom_type: "mcp_content_rule_updated").count).to eq(2)
    end
  end

  describe "DELETE /admin/mcp/content-restrictions/:rule_kind.json" do
    %w[private_messages u6:gone u6:offline].each do |name|
      it "[cr-u6] deletes #{name} with a staff log and returns 404 when repeated" do
        register_rule("u6:offline", availability: -> { false })
        row = McpContentRule.create!(rule_kind: name, config: {})
        delete "/admin/mcp/content-restrictions/#{name}.json"
        expect(response.status).to eq(204)
        expect(response.body).to eq("")
        expect(McpContentRule.exists?(row.id)).to eq(false)
        log = history("mcp_content_rule_deleted")
        expect(log).to be_present
        expect(log.acting_user_id).to eq(admin.id)
        expect(log.action).to eq(UserHistory.actions[:custom_staff])
        expect(log.details).to include(name)
        delete "/admin/mcp/content-restrictions/#{name}.json"
        expect(response.status).to eq(404)
        expect(UserHistory.where(custom_type: "mcp_content_rule_deleted").count).to eq(1)
      end
    end
  end

  describe "admin authorization" do
    %i[moderator user].each do |role|
      it "[cr-u6] gives #{role}s 404 for content routes and existing admin MCP payloads without mutation" do
        viewer = Fabricate(role)
        row = McpContentRule.create!(rule_kind: "private_messages", config: {})
        content_get
        sign_in(viewer)
        before_history = UserHistory.count
        previous_attributes = row.attributes
        aggregate_failures do
          %w[content-restrictions capabilities access overview].each do |endpoint|
            get "/admin/mcp/#{endpoint}.json"
            expect(response.status).to eq(404)
          end
          put "/admin/mcp/content-restrictions/private_messages.json",
              params: {
                config: {
                },
              },
              as: :json
          expect(response.status).to eq(404)
          delete "/admin/mcp/content-restrictions/private_messages.json"
          expect(response.status).to eq(404)
          expect(row.reload.attributes).to eq(previous_attributes)
          expect(UserHistory.count).to eq(before_history)
        end
      end
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
