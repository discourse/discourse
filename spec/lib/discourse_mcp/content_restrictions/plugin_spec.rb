# frozen_string_literal: true

describe Plugin::Instance do
  def loaded_plugin(name)
    Discourse.plugins_by_name[name].tap { |plugin| skip "#{name} is not loaded" if plugin.nil? }
  end

  it "[cr-u1] registers plugin data and rule kinds under the plugin provider and treats disabled plugins as orphans" do
    skip "Plugins are not loaded" if Discourse.plugins_by_name.empty?
    registry = DiscourseMcp::Registry.new
    allow(DiscourseMcp).to receive(:registry).and_return(registry)
    registry.register_content_data_kind("exit_paths", provider: "core")
    metadata = Plugin::Metadata.new
    metadata.name = "oracle-plugin"
    plugin = Plugin::Instance.new(metadata, "/tmp/oracle-plugin/plugin.rb")
    plugin.enabled_site_setting(:mcp_server_enabled)
    SiteSetting.mcp_server_enabled = true
    plugin.register_mcp_content_data_kind("oracle-plugin:messages", touched_by: ["foreign_tool"])
    attrs = {
      affected_data_kinds: ["oracle-plugin:messages"],
      config_contract: {
        type: "object",
        additionalProperties: false,
      },
      compile: ->(_config) { ->(**) { false } },
      admin_component_id: "oracle-plugin-editor",
    }
    plugin.register_mcp_content_rule_kind("oracle-plugin:rule", **attrs)
    primitive =
      plugin.register_mcp_tool(
        "oracle_plugin_tool",
        title: "Plugin oracle",
        description: "Plugin content declaration",
        implementation: ->(**) { {} },
        content: {
          "oracle-plugin:messages" => :untouched,
          "exit_paths" => :untouched,
        },
      )
    expect(primitive.provider).to eq(metadata.name)
    expect { plugin.register_mcp_content_data_kind("other:messages") }.to raise_error(ArgumentError)
    expect { plugin.register_mcp_content_rule_kind("other:rule", **attrs) }.to raise_error(
      ArgumentError,
    )
    McpContentRule.create!(rule_kind: "oracle-plugin:rule", config: {})
    expect(DiscourseMcp::ContentPolicy.load).not_to be_orphaned
    expect(DiscourseMcp.primitive_usable?(primitive)).to eq(true)
    SiteSetting.mcp_server_enabled = false
    expect(DiscourseMcp::ContentPolicy.load).to be_orphaned
    SiteSetting.mcp_server_enabled = true
    expect(DiscourseMcp::ContentPolicy.load).not_to be_orphaned
    plugin.register_mcp_content_rule_kind(
      "oracle-plugin:unavailable",
      **attrs,
      availability: -> { false },
    )
    McpContentRule.create!(rule_kind: "oracle-plugin:unavailable", config: {})
    expect(DiscourseMcp::ContentPolicy.load).to be_orphaned
  end

  shared_examples "a plugin content declaration" do |provider, identifier|
    it "[cr-u1] declares all five core data kinds for #{provider}" do
      loaded_plugin(provider)
      primitive = DiscourseMcp.registry.find(:tool, identifier)
      expect(primitive).to be_present
      expect(primitive.provider).to eq(provider)
      expect(primitive.content).to be_a(Hash)
      expect(primitive.content.keys).to contain_exactly(
        "topics",
        "private_messages",
        "categories",
        "tags",
        "exit_paths",
      )
    end
  end

  include_examples "a plugin content declaration",
                   "discourse-reactions",
                   "discourse_reactions_post_reaction_set"
  include_examples "a plugin content declaration",
                   "discourse-solved",
                   "discourse_solved_solution_set"
  include_examples "a plugin content declaration",
                   "discourse-topic-voting",
                   "discourse_topic_voting_vote_set"
  include_examples "a plugin content declaration",
                   "discourse-events",
                   "discourse_calendar_event_list"

  it "[cr-u1] blocks Data Explorer execution as unbounded while allowing query-definition reads as none" do
    loaded_plugin("discourse-data-explorer")
    execute = DiscourseMcp.registry.find(:tool, "discourse_run_query")
    read = DiscourseMcp.registry.find(:tool, "discourse_get_query")
    expect(execute.content).to eq(:unbounded)
    expect(read.content).to eq(:none)
    expect(DiscourseMcp.primitive_usable?(execute)).to eq(true)
    McpContentRule.create!(rule_kind: "private_messages", config: {})
    expect(DiscourseMcp.primitive_usable?(execute)).to eq(false)
    expect(DiscourseMcp.primitive_usable?(read)).to eq(true)
  end

  it "[cr-u1] leaves every chat primitive undeclared and blocked under an active rule" do
    loaded_plugin("chat")
    primitives = DiscourseMcp.registry.all.select { |primitive| primitive.provider == "chat" }
    expect(primitives.map(&:identifier)).to contain_exactly(
      "chat_channel_list",
      "discourse_get_chat_messages",
      "chat_message_create",
    )
    McpContentRule.create!(rule_kind: "private_messages", config: {})
    primitives.each do |primitive|
      expect(primitive.content).to be_nil
      expect(DiscourseMcp.primitive_usable?(primitive)).to eq(false)
    end
  end

  it "[cr-u1] reports AI theme access unavailable when exposed theme tools are gate-blocked" do
    loaded_plugin("discourse-ai")
    SiteSetting.mcp_server_enabled = true
    %w[discourse_get_theme discourse_create_theme discourse_update_theme].each do |identifier|
      McpPrimitive.find_or_create_by!(kind: "tool", identifier:).update!(enabled: true)
    end
    expect(DiscourseAi::Agents::McpThemeAccess.ready?).to eq(true)
    McpContentRule.create!(rule_kind: "private_messages", config: {})
    expect(DiscourseAi::Agents::McpThemeAccess.ready?).to eq(false)
  end

  shared_examples "a plugin PM mutation oracle" do |provider, identifier, setting, arguments|
    it "[cr-u1] makes #{provider} mutations answer identically for PM and nonexistent IDs" do
      loaded_plugin(provider)
      SiteSetting.public_send("#{setting}=", true)
      SiteSetting.mcp_server_enabled = true
      admin = Fabricate(:admin, refresh_auto_groups: true)
      canary = "pluginsecret#{SecureRandom.hex(10)}"
      message = Fabricate(:private_message_post, user: admin, raw: "Plugin PM #{canary}")
      key = provider == "discourse-topic-voting" ? :topic_id : :post_id
      private_id = key == :topic_id ? message.topic_id : message.id
      model = key == :topic_id ? Topic : Post
      missing_id = model.unscoped.maximum(:id) + 10_000
      original = message.attributes
      client =
        McpOauthClient.create!(
          client_id: SecureRandom.hex,
          name: "Plugin policy oracle",
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
      raw_token = McpOauthAccessToken.issue!(authorization:)
      token = McpOauthAccessToken.find_by!(token_hash: McpOauthAccessToken.digest(raw_token))
      McpPrimitive.find_or_create_by!(kind: "tool", identifier:).update!(enabled: true)
      McpContentRule.create!(rule_kind: "private_messages", config: {})
      request = ActionDispatch::TestRequest.create
      request.headers["MCP-Protocol-Version"] = DiscourseMcp::LEGACY_PROTOCOL_VERSION
      responses =
        [private_id, missing_id].map do |id|
          DiscourseMcp::Server.new(
            request:,
            request_context: DiscourseMcp::RequestContext.new(token),
          ).call(
            {
              "jsonrpc" => "2.0",
              "id" => 1,
              "method" => "tools/call",
              "params" => {
                "name" => identifier,
                "arguments" => arguments.merge(key => id).deep_stringify_keys,
              },
            },
          )
        end
      expect(responses.first).to eq(responses.last)
      expect(responses.first.http_status).to be < 500
      expect(responses.first.headers.keys.map(&:downcase)).not_to include("www-authenticate")
      expect(JSON.generate(responses.first.to_h)).not_to include(canary, message.raw)
      expect(message.reload.attributes).to eq(original)
    end
  end

  include_examples "a plugin PM mutation oracle",
                   "discourse-reactions",
                   "discourse_reactions_post_reaction_set",
                   :discourse_reactions_enabled,
                   { reaction: "heart" }
  include_examples "a plugin PM mutation oracle",
                   "discourse-solved",
                   "discourse_solved_solution_set",
                   :solved_enabled,
                   { accepted: true }
  include_examples "a plugin PM mutation oracle",
                   "discourse-topic-voting",
                   "discourse_topic_voting_vote_set",
                   :topic_voting_enabled,
                   { voted: true }
end
