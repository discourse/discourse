# frozen_string_literal: true

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe Admin::McpController, type: :request do
  def forum_config
    {
      "allow" => {
        "mode" => "all",
        "category_ids" => [],
        "tag_ids" => [],
      },
      "deny" => {
        "category_ids" => [],
        "tag_ids" => [],
      },
    }
  end

  def register_rule(name, **options)
    registry.register_content_rule_kind(
      name,
      provider: "u6",
      affected_data_kinds: ["topics"],
      config_contract: {
        type: "object",
        additionalProperties: false,
      },
      compile: ->(_config) { DiscourseMcp::ContentPolicy::Evaluator.new },
      **options,
    )
  end

  def register_primitive(
    identifier,
    content:,
    kind: :tool,
    enabled: true,
    blocked: false,
    available: true
  )
    registry.register(
      identifier: identifier,
      kind: kind,
      title: identifier,
      description: "Content restriction request fixture",
      implementation: ->(**) { raise "Request fixtures must not invoke primitives" },
      content: content,
      availability: -> { available },
      required_scopes: ["mcp:profile:read"],
    )
    McpPrimitive.create!(
      kind: kind,
      identifier: identifier,
      enabled: enabled,
      emergency_blocked: blocked,
    )
  end

  def rule_entry(name)
    response.parsed_body.fetch("rule_kinds").find { |entry| entry.fetch("name") == name }
  end

  def history(action)
    UserHistory.where(custom_type: action).order(:id).last
  end

  def primitive_id(identifier, kind = :tool)
    "#{kind}:#{identifier}"
  end

  def content_get
    get "/admin/mcp/content-restrictions.json"
    expect(response.status).to eq(200)
  end

  fab!(:admin)
  let(:registry) { DiscourseMcp::Registry.new }
  let(:untouched) do
    %w[topics categories tags private_messages exit_paths].index_with { :untouched }
  end
  let(:filtered) { untouched.merge("topics" => :enforced, "private_messages" => :enforced) }

  before do
    McpContentRule.delete_all
    McpPrimitive.delete_all
    SiteSetting.mcp_server_enabled = true
    SiteSetting.tagging_enabled = true
    DiscourseMcp::CorePrimitives.register_content_kinds(registry)
    allow(DiscourseMcp).to receive(:registry).and_return(registry)
    register_primitive("u6_none", content: :none)
    register_primitive("u6_untouched", content: untouched)
    register_primitive("u6_filtered", content: filtered)
    register_primitive("u6_forum", content: untouched.merge("topics" => :unenforced))
    register_primitive("u6_pm", content: untouched.merge("private_messages" => :unenforced))
    register_primitive("u6_exit", content: untouched.merge("exit_paths" => :unenforced))
    register_primitive("u6_undeclared", content: nil)
    register_primitive("u6_unbounded", content: :unbounded)
    register_primitive("u6_disabled", content: nil, enabled: false)
    register_primitive("u6_emergency", content: nil, blocked: true)
    register_primitive("u6_unavailable", content: nil, available: false)
    register_primitive("u6_resource", content: nil, kind: :resource)
    register_primitive("u6_template", content: filtered, kind: :resource_template)
    register_primitive("u6_prompt", content: nil, kind: :prompt)
  end

  describe "GET /admin/mcp/content-restrictions.json" do
    before { sign_in(admin) }

    it "lists registered kinds in registration order with string component ids and inactive metadata" do
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

    it "reports active stored config timestamp and updater including a null updater" do
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

    it "resolves both reference sides and reports missing ids once without expanding subtrees" do
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

    it "computes per-rule impact from declarations across primitive kinds and exposure states" do
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

    it "computes marginal impact against active rules and the orphan veto" do
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

    it "lists unregistered and unavailable orphans and restores the PM override on removal" do
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
    before { sign_in(admin) }

    it "creates and replaces one row with the actor and returns the full GET payload" do
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

    it "resolves tag names on both sides and replaces the entire forum config" do
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

    it "validates a registered provider contract rather than hardcoding core kinds" do
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
      it "refuses #{failure} without storing a new row or replacing an existing config" do
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

    it "refuses writes to unregistered and unavailable kinds with 404" do
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

    it "logs the rule and exactly the newly disabled primitive ids" do
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

    context "with tag names", aggregate_failures: true do
      %w[allow deny].each do |side|
        it "applies #{side} synonym names to topics carrying the canonical tag" do
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
          it "refuses #{side} #{shape} tag input on create and replace without storage or logs" do
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

      it "controls valid names empty arrays numeric ids and unknown or non-string scalar names" do
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
    end

    context "when logging stored configs", aggregate_failures: true do
      it "logs a new forum rule's normalized stored config" do
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

      it "logs previous and new stored configs when a forum rule is relaxed" do
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

    context "with tag ids and raw JSON tag names", aggregate_failures: true do
      %w[allow deny].each do |side|
        it "applies #{side} synonym ids to topics carrying the canonical tag" do
          canonical = Fabricate(:tag, id: 114_620_051, name: "u6r3-canonical")
          synonym = Fabricate(:tag, id: 114_620_052, name: "u6r3-synonym", target_tag: canonical)
          tagged = Fabricate(:topic, id: 114_620_053, tags: [canonical])
          other = Fabricate(:topic, id: 114_620_054)
          config = forum_config
          config[side]["tag_ids"] = [synonym.id]
          config["allow"]["mode"] = "selected" if side == "allow"

          put "/admin/mcp/content-restrictions/forum_content.json", params: { config: }, as: :json

          expect(response.status).to eq(200)
          expect(McpContentRule.find_by!(rule_kind: "forum_content")).to be_persisted
          visible =
            DiscourseMcp::ContentPolicy.load.scope_topics(Topic.where(id: [tagged.id, other.id]))
          expect(visible.pluck(:id)).to eq([side == "allow" ? tagged.id : other.id])
        end

        it "controls #{side} ordinary ids and refuses missing ids on create and replace" do
          tag = Fabricate(:tag, id: 114_620_061, name: "u6r3-ordinary")
          tagged = Fabricate(:topic, id: 114_620_063, tags: [tag])
          other = Fabricate(:topic, id: 114_620_064)
          config = forum_config
          config[side]["tag_ids"] = [tag.id]
          config["allow"]["mode"] = "selected" if side == "allow"

          put "/admin/mcp/content-restrictions/forum_content.json", params: { config: }, as: :json

          expect(response.status).to eq(200)
          expect(McpContentRule.find_by!(rule_kind: "forum_content").config).to eq(config)
          visible =
            DiscourseMcp::ContentPolicy.load.scope_topics(Topic.where(id: [tagged.id, other.id]))
          expect(visible.pluck(:id)).to eq([side == "allow" ? tagged.id : other.id])
          expect(Tag.exists?(114_620_099)).to eq(false)
          bad = config.deep_dup
          bad[side]["tag_ids"] = [114_620_099]

          [true, false].each do |replacing|
            McpContentRule.delete_all if !replacing
            before_rows = McpContentRule.order(:id).map(&:attributes)
            before_logs = UserHistory.order(:id).pluck(:id)

            put "/admin/mcp/content-restrictions/forum_content.json",
                params: {
                  config: bad,
                },
                as: :json

            aggregate_failures("#{replacing ? "replace" : "create"} missing-id refusal") do
              expect(response.status).to be_between(400, 499)
              expect(response.parsed_body["errors"]).to be_present
              expect(McpContentRule.order(:id).map(&:attributes)).to eq(before_rows)
              expect(UserHistory.order(:id).pluck(:id)).to eq(before_logs)
            end
          end
        end

        {
          "null only" => [nil],
          "known name then null" => ["u6r3-known", nil],
        }.each do |shape, names|
          %w[create replace].each do |operation|
            it "refuses raw JSON #{side} #{shape} on #{operation} without storage or logs" do
              Fabricate(:tag, id: 114_620_071, name: "u6r3-known")
              retained = Fabricate(:tag, id: 114_620_072, name: "u6r3-retained")
              previous = forum_config
              previous[side]["tag_ids"] = [retained.id]
              previous["allow"]["mode"] = "selected" if side == "allow"
              if operation == "replace"
                put "/admin/mcp/content-restrictions/forum_content.json",
                    params: {
                      config: previous,
                    },
                    as: :json
                expect(response.status).to eq(200)
                expect(McpContentRule.find_by!(rule_kind: "forum_content").config).to eq(previous)
              end
              bad = forum_config
              bad["allow"]["mode"] = "selected" if side == "allow"
              bad[side].delete("tag_ids")
              bad[side]["tag_names"] = names
              before_rows = McpContentRule.order(:id).map(&:attributes)
              before_logs = UserHistory.order(:id).pluck(:id)

              put "/admin/mcp/content-restrictions/forum_content.json",
                  params: { config: bad }.to_json,
                  headers: {
                    "CONTENT_TYPE" => "application/json",
                  }

              expect(response.status).to eq(400)
              expect(response.parsed_body["errors"]).to be_present
              expect(McpContentRule.order(:id).map(&:attributes)).to eq(before_rows)
              expect(UserHistory.order(:id).pluck(:id)).to eq(before_logs)
            end
          end
        end

        it "saves raw JSON #{side} empty names and clears an existing tag list" do
          tag = Fabricate(:tag, id: 114_620_081, name: "u6r3-clear")
          config = forum_config
          config["allow"]["mode"] = "selected" if side == "allow"
          config[side].delete("tag_ids")
          config[side]["tag_names"] = []

          [false, true].each do |replacing|
            if replacing
              previous = forum_config
              previous[side]["tag_ids"] = [tag.id]
              previous["allow"]["mode"] = "selected" if side == "allow"
              put "/admin/mcp/content-restrictions/forum_content.json",
                  params: {
                    config: previous,
                  },
                  as: :json
              expect(response.status).to eq(200)
              expect(McpContentRule.find_by!(rule_kind: "forum_content").config).to eq(previous)
            end

            put "/admin/mcp/content-restrictions/forum_content.json",
                params: { config: }.to_json,
                headers: {
                  "CONTENT_TYPE" => "application/json",
                }

            expect(response.status).to eq(200)
            expected = forum_config
            expected["allow"]["mode"] = "selected" if side == "allow"
            expect(McpContentRule.find_by!(rule_kind: "forum_content").config).to eq(expected)
          end
        end
      end
    end

    context "with raw JSON id lists", aggregate_failures: true do
      %w[allow deny].each do |side|
        %w[tag_ids category_ids].each do |field|
          [
            "whole float",
            "mixed integer and whole float",
            "fractional float",
            "string",
            "null",
            "true",
            "false",
            "object",
            "array",
          ].each do |shape|
            %w[create replace].each do |operation|
              it "refuses raw JSON #{side}.#{field} #{shape} on #{operation} without storage or logs" do
                if field == "tag_ids"
                  canonical = Fabricate(:tag, id: 114_620_101, name: "u6r4-canonical")
                  first =
                    Fabricate(:tag, id: 114_620_102, name: "u6r4-synonym", target_tag: canonical)
                  second = Fabricate(:tag, id: 114_620_103, name: "u6r4-ordinary")
                else
                  first = Fabricate(:category, id: 114_620_111)
                  second = Fabricate(:category, id: 114_620_112)
                end
                if operation == "replace"
                  retained = Fabricate(:tag, id: 114_620_104, name: "u6r4-retained")
                  previous = forum_config
                  previous["deny"]["tag_ids"] = [retained.id]

                  put "/admin/mcp/content-restrictions/forum_content.json",
                      params: { config: previous }.to_json,
                      headers: {
                        "CONTENT_TYPE" => "application/json",
                      }

                  expect(response.status).to eq(200)
                  expect(McpContentRule.find_by!(rule_kind: "forum_content").config).to eq(previous)
                end
                bad = forum_config
                bad["allow"]["mode"] = "selected" if side == "allow"
                bad[side][field] = case shape
                when "whole float"
                  [first.id.to_f]
                when "mixed integer and whole float"
                  [first.id, second.id.to_f]
                when "fractional float"
                  [first.id + 0.5]
                when "string"
                  [first.id.to_s]
                when "null"
                  [nil]
                when "true"
                  [true]
                when "false"
                  [false]
                when "object"
                  [{ "id" => first.id }]
                when "array"
                  [[first.id]]
                end
                before_rows = McpContentRule.order(:id).map(&:attributes)
                before_logs = UserHistory.order(:id).pluck(:id)

                put "/admin/mcp/content-restrictions/forum_content.json",
                    params: { config: bad }.to_json,
                    headers: {
                      "CONTENT_TYPE" => "application/json",
                    }

                expect(response.status).to eq(400)
                expect(response.parsed_body["errors"]).to be_present
                expect(McpContentRule.order(:id).map(&:attributes)).to eq(before_rows)
                expect(UserHistory.order(:id).pluck(:id)).to eq(before_logs)
              end
            end
          end

          it "saves raw JSON integer #{side}.#{field} on create and replace with topic visibility" do
            if field == "tag_ids"
              first = Fabricate(:tag, id: 114_620_101, name: "u6r4-canonical")
              second = Fabricate(:tag, id: 114_620_103, name: "u6r4-ordinary")
              matched = Fabricate(:topic, id: 114_620_121, tags: [first])
              another = Fabricate(:topic, id: 114_620_122, tags: [second])
            else
              first = Fabricate(:category, id: 114_620_111)
              second = Fabricate(:category, id: 114_620_112)
              matched = Fabricate(:topic, id: 114_620_121, category: first)
              another = Fabricate(:topic, id: 114_620_122, category: second)
            end
            other = Fabricate(:topic, id: 114_620_123)
            retained = Fabricate(:tag, id: 114_620_104, name: "u6r4-retained")
            config = forum_config
            config["allow"]["mode"] = "selected" if side == "allow"
            config[side][field] = [first.id, second.id]

            %w[create replace].each do |operation|
              if operation == "replace"
                previous = forum_config
                previous["deny"]["tag_ids"] = [retained.id]
                put "/admin/mcp/content-restrictions/forum_content.json",
                    params: { config: previous }.to_json,
                    headers: {
                      "CONTENT_TYPE" => "application/json",
                    }
                expect(response.status).to eq(200)
                expect(McpContentRule.find_by!(rule_kind: "forum_content").config).to eq(previous)
              end
              before_logs = UserHistory.order(:id).pluck(:id)

              put "/admin/mcp/content-restrictions/forum_content.json",
                  params: { config: }.to_json,
                  headers: {
                    "CONTENT_TYPE" => "application/json",
                  }

              aggregate_failures(operation) do
                expect(response.status).to eq(200)
                expect(McpContentRule.find_by!(rule_kind: "forum_content").config).to eq(config)
                expect(UserHistory.order(:id).pluck(:id).size).to eq(before_logs.size + 1)
                visible =
                  DiscourseMcp::ContentPolicy.load.scope_topics(
                    Topic.where(id: [matched.id, another.id, other.id]),
                  )
                expect(visible.pluck(:id)).to contain_exactly(
                  *(side == "allow" ? [matched.id, another.id] : [other.id]),
                )
              end
            end
          end
        end
      end
    end
  end

  describe "DELETE /admin/mcp/content-restrictions/:rule_kind.json" do
    before { sign_in(admin) }

    %w[private_messages u6:gone u6:offline].each do |name|
      it "deletes #{name} with a staff log and returns 404 when repeated" do
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

    it "logs the removed stored config when a forum rule is deleted", aggregate_failures: true do
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

  describe "revoked scope impact across admin requests", aggregate_failures: true do
    before { sign_in(admin) }

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
          description: "Scoped content restriction fixture",
          implementation: ->(**) { raise "Request fixtures must not invoke primitives" },
          content:,
          required_scopes: scopes,
          availability: -> { available },
        )
        McpPrimitive.create!(identifier:, kind:, enabled:, emergency_blocked: blocked)
      end
      register_rule("u6:scoped_offline", availability: -> { false })
    end

    %w[private_messages u6:scoped_offline].each do |rule_kind|
      it "reports revoked-scope primitives as disabled rather than restricted for #{rule_kind}" do
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
        it "marks revoked-scope primitives restricted in #{endpoint} under #{rule_kind}" do
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

      it "counts revoked-scope primitives as blocked and removes them from the #{rule_kind} catalog" do
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

    it "logs exactly newly disabled ids including revoked scopes and respects an existing orphan" do
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
      McpContentRule.create!(rule_kind: "u6:scoped_offline", config: {})
      put "/admin/mcp/content-restrictions/private_messages.json", params: { config: {} }, as: :json
      expect(response.status).to eq(200)
      expect(
        history("mcp_content_rule_updated").details.scan(
          /(?:tool|resource_template|resource|prompt):[A-Za-z0-9_.-]+/,
        ),
      ).to eq([])
    end

    it "controls scoped primitives with no rule a forum-only rule and after PM removal" do
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

  describe "stored forum_content topic visibility", aggregate_failures: true do
    %w[allow deny].each do |side|
      it "applies directly stored #{side} synonym ids to topics carrying the target tag" do
        canonical = Fabricate(:tag, id: 114_620_101, name: "u6r4-canonical")
        synonym = Fabricate(:tag, id: 114_620_102, name: "u6r4-synonym", target_tag: canonical)
        ordinary = Fabricate(:tag, id: 114_620_103, name: "u6r4-ordinary")
        tagged = Fabricate(:topic, id: 114_620_121, tags: [canonical])
        another = Fabricate(:topic, id: 114_620_122, tags: [ordinary])
        other = Fabricate(:topic, id: 114_620_123)
        config = forum_config
        config["allow"]["mode"] = "selected" if side == "allow"
        config[side]["tag_ids"] = [synonym.id, ordinary.id]
        row =
          McpContentRule.create!(
            rule_kind: "forum_content",
            config: forum_config,
            updated_by: admin,
          )
        row.update_columns(config: config)

        expect(row.reload.config).to eq(config)
        visible =
          DiscourseMcp::ContentPolicy.load.scope_topics(
            Topic.where(id: [tagged.id, another.id, other.id]),
          )

        expect(visible.pluck(:id)).to contain_exactly(
          *(side == "allow" ? [tagged.id, another.id] : [other.id]),
        )
      end
    end
  end

  %w[capabilities access].each do |endpoint|
    describe "GET /admin/mcp/#{endpoint}.json" do
      before { sign_in(admin) }

      it "adds false restricted flags to #{endpoint} with no rows and preserves admin choices" do
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

      it "reports policy restrictions in #{endpoint} separately from enabled and emergency states" do
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

      it "reports the orphan veto in #{endpoint} while leaving content-free primitives usable" do
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
    before { sign_in(admin) }

    it "preserves the no-rule catalog and adds an inactive zero-blocked summary" do
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

    it "counts only policy-usable exposed catalog entries and restores them after removal" do
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

    it "counts orphan-blocked exposed entries once even with multiple orphan rows" do
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

  describe "admin authorization" do
    before { sign_in(admin) }

    %i[moderator user].each do |role|
      it "gives #{role}s 404 for content routes and existing admin MCP payloads without mutation" do
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
