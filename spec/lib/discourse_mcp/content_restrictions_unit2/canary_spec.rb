# frozen_string_literal: true

require_relative "canary_support"
require_relative "assertions"

describe DiscourseMcp::Server, "#call [cr-u2] live-registry canaries" do
  include McpContentRestrictionsUnit2::Assertions

  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }

  before do
    SiteSetting.mcp_server_enabled = true
    SiteSetting.tagging_enabled = true
    SiteSetting.enable_user_status = true
    SiteSetting.enable_badges = true
    SiteSetting.authorized_extensions = "txt|png"
    SiteSetting.allow_new_registrations = true
    {
      discourse_reactions_enabled: true,
      discourse_reactions_enabled_reactions: "laughing",
      solved_enabled: true,
      allow_solved_on_all_topics: true,
      topic_voting_enabled: true,
      discourse_events_enabled: true,
      discourse_post_event_enabled: true,
      data_explorer_enabled: true,
      chat_enabled: true,
    }.each do |setting, value|
      SiteSetting.public_send("#{setting}=", value) if SiteSetting.respond_to?("#{setting}=")
    end
  end

  let(:client) do
    McpOauthClient.create!(
      client_id: SecureRandom.hex,
      name: "Unit 2 canary administrator",
      registration_type: "pre_registered",
      trust_state: "approved",
      redirect_uris: ["http://127.0.0.1/callback"],
    )
  end
  let(:authorization) do
    DiscourseMcp::OAuth::AuthorizationGrant.create!(
      user: admin,
      client:,
      redirect_uri: client.redirect_uris.first,
      requested_scopes: DiscourseMcp.registry.scopes,
    )
  end
  let(:token) do
    raw = McpOauthAccessToken.issue!(authorization:)
    McpOauthAccessToken.find_by!(token_hash: McpOauthAccessToken.digest(raw))
  end

  def primitive_key(primitive)
    "#{primitive.kind}:#{primitive.identifier}"
  end

  def expose(primitive)
    McpPrimitive.find_or_create_by!(
      kind: primitive.kind.to_s,
      identifier: primitive.identifier,
    ).update!(enabled: true)
  end

  def rpc(primitive, arguments, rollback: true)
    expose(primitive)
    method, params =
      case primitive.kind
      when :tool
        ["tools/call", { name: primitive.identifier, arguments: }]
      when :prompt
        ["prompts/get", { name: primitive.identifier, arguments: }]
      when :resource_template
        ["resources/read", { uri: arguments.fetch("uri") }]
      else
        raise "Add a Server dispatcher for #{primitive.kind}"
      end
    request = ActionDispatch::TestRequest.create
    request.headers["MCP-Protocol-Version"] = DiscourseMcp::LEGACY_PROTOCOL_VERSION
    access_token = token
    settings = SiteSetting.provider.all.map(&:dup)
    response = nil
    ActiveRecord::Base.transaction(requires_new: true) do
      begin
        result =
          DiscourseMcp::Server.new(
            request:,
            request_context: DiscourseMcp::RequestContext.new(access_token),
          ).call(
            {
              "jsonrpc" => "2.0",
              "id" => 1,
              "method" => method,
              "params" => params.deep_stringify_keys,
            },
          )
        response =
          JSON.parse(
            JSON.generate(status: result.http_status, headers: result.headers, body: result.body),
          )
      ensure
        Scheduler::Defer.do_all_work
      end
      raise ActiveRecord::Rollback if rollback
    end
    response
  ensure
    if rollback && settings
      SiteSetting.provider.clear
      settings.each do |setting|
        SiteSetting.provider.save(setting.name, setting.value, setting.data_type)
      end
      SiteSetting.refresh!
      MessageBus::DistributedCache.default_manager.subscribers.each do |cache|
        cache.hash.clear if cache.weakref_alive?
      end
      Discourse.redis.flushdb
      Sidekiq::Worker.clear_all
    end
  end

  def expect_usable(response)
    expect(response.fetch("status")).to eq(200), response.inspect
    expect(response.dig("body", "error")).to be_nil, response.inspect
    expect(response.dig("body", "result", "isError")).not_to eq(true), response.inspect
    expect(response.dig("body", "result")).to be_present
  end

  def add_redirect_canary(data)
    target = data.redirect_target
    expect(data.restricted_posts).to include(target)
    expect(data.restricted_tokens).to include(data.tokens.fetch(:redirect_target))
    url = "https://cr-u2.example/redirect/#{SecureRandom.hex(8)}"
    IPSocket.stubs(:getaddress).returns("100.2.3.4")
    stub_request(:get, url).to_return(status: 302, headers: { "Location" => target.full_url })
    stub_request(:get, target.full_url).to_return(
      status: 200,
      body: "<html><title>#{target.topic.title}</title></html>",
    )
    primitive = DiscourseMcp.registry.find(:tool, "discourse_create_post")
    response =
      rpc(
        primitive,
        { "topic_id" => data.allowed_post.topic_id, "raw" => "Fresh labeled [reference](#{url})" },
        rollback: false,
      )
    expect_usable(response)
    post = Post.find(response.dig("body", "result", "structuredContent", "id"))
    TopicLink.extract_from(post)
    link = TopicLink.find_by!(post_id: post.id, url:)
    Jobs::CrawlTopicLink.new.execute(topic_link_id: link.id)
    expect(link.reload.title).to eq(target.topic.title)
    summary = DiscourseMcp.registry.find(:tool, "discourse_get_user_summary")
    baseline =
      rpc(
        summary,
        data.resolve(
          McpContentRestrictionsUnit2::FIXTURES.fetch("tool:discourse_get_user_summary").fetch(
            "arguments",
          ),
        ),
      )
    expect_usable(baseline)
    expect(baseline.dig("body", "result", "structuredContent", "top_links")).to include(
      a_hash_including("url" => url, "title" => target.topic.title),
    )
    expect(JSON.generate(baseline)).to include(data.tokens.fetch(:redirect_target))
  end

  def probe_primitive(data, key, fixture)
    configuration = data.configuration
    cell = "#{configuration} #{key}"
    kind, identifier = key.split(":", 2)
    primitive = DiscourseMcp.registry.find(kind, identifier)
    if !primitive
      if ENV["LOAD_PLUGINS"] != "1"
        RSpec.configuration.reporter.message("[cr-u2] skipped #{key}: plugin not loaded")
        return
      end
      raise "Registered fixture disappeared: #{key}"
    end
    expect(primitive.available?).to eq(true),
    "Fixture must enable #{key}'s availability prerequisite"
    arguments = data.resolve(fixture.fetch("arguments"))
    schema = JSONSchemer.schema(primitive.input_schema)
    expect(schema.validate(arguments).to_a).to eq([])
    expected = fixture.fetch("availability").fetch(configuration)
    response = rpc(primitive, arguments)
    expect_clean(response, data, cell:)
    if expected == "usable"
      expect_usable(response)
    else
      expect_blocked(response, server_version: Discourse::VERSION::STRING)
    end
    fixture
      .fetch("ids")
      .each do |field, classification|
        next if !classification["target"]
        data
          .targets(classification.fetch("target"))
          .each do |restricted_id, missing_id|
            overrides = field == "post_ids" ? { "selection_mode" => "post_ids" } : {}
            restricted_arguments =
              arguments_with_identifier(arguments.merge(overrides), fixture, field, restricted_id)
            missing_arguments =
              arguments_with_identifier(arguments.merge(overrides), fixture, field, missing_id)
            [restricted_arguments, missing_arguments].each do |variant|
              expect(schema.validate(variant).to_a).to eq([])
            end
            restricted_response = rpc(primitive, restricted_arguments)
            missing_response = rpc(primitive, missing_arguments)
            comparable_response =
              response_without_request_echo(
                restricted_response,
                field:,
                supplied: restricted_id,
                replacement: missing_id,
                echoes: fixture.fetch("request_echoes", {}),
              )
            expect_clean(comparable_response, data, cell:)
            expect_clean(missing_response, data, cell:)
            expect(comparable_response).to eq(missing_response),
            "#{key} #{field}: restricted=#{restricted_id.inspect}; missing=#{missing_id.inspect}"
            if expected == "blocked"
              expect_blocked(restricted_response, server_version: Discourse::VERSION::STRING)
            end
          end
      end
    if %w[
         discourse_get_user_summary
         discourse_list_user_posts
         discourse_list_user_actions
       ].include?(identifier)
      username =
        if identifier == "discourse_get_user_summary"
          data.values.fetch("restricted_author_username")
        else
          admin.username
        end
      additional_response = rpc(primitive, arguments.merge("username" => username))
      expect_clean(additional_response, data, cell:)
      expect_usable(additional_response)
    end
    if identifier == "discourse_get_reviewable"
      conversation_reviewable = data.conversation_reviewable
      conversation_response =
        rpc(primitive, arguments.merge("reviewable_id" => conversation_reviewable.id))
      expect_clean(conversation_response, data, cell:)
      expect_usable(conversation_response)
    end
  end

  it "[cr-u2] seeds every canary and proves its content is observable before restrictions" do
    data = McpContentRestrictionsUnit2::CanaryData.new(admin, "pm_off")
    add_redirect_canary(data)
    expect(data.posts.keys).to contain_exactly(
      :outside_allowlist,
      :denied_subcategory,
      :tagged_after_index,
      :private_message,
      :tagged_definition,
      :restricted_author,
      :membership_request,
      :reviewable_conversation,
      :redirect_target,
    )
    expect(data.tokens.values.uniq.length).to eq(data.posts.length)
    reader = DiscourseMcp.registry.find(:tool, "discourse_read_post")
    data.posts.each do |name, post|
      response = rpc(reader, { "post_id" => post.id })
      expect_usable(response)
      expect(JSON.generate(response)).to include(data.tokens.fetch(name))
      records = data.related.fetch(name)
      expect(records.keys).to contain_exactly(
        :notification,
        :action,
        :bookmark,
        :draft,
        :reviewable,
        :revision,
        :badge,
        :webhook_event,
        :upload,
      )
      expect(records.values).to all(be_persisted)
    end
    expect(McpOauthAccessToken.exists?(token.id)).to eq(true)
    original_title = data.allowed_post.topic.title
    update_topic = DiscourseMcp.registry.find(:tool, "discourse_update_topic")
    expect_usable(
      rpc(
        update_topic,
        {
          "topic_id" => data.allowed_post.topic_id,
          "title" => "A temporary calibration topic title",
        },
      ),
    )
    expect(data.allowed_post.topic.reload.title).to eq(original_title)
    read_topic = DiscourseMcp.registry.find(:tool, "discourse_read_topic")
    expect(JSON.generate(rpc(read_topic, { "topic_id" => data.allowed_post.topic_id }))).to include(
      original_title,
    )
    update_setting = DiscourseMcp.registry.find(:tool, "discourse_update_site_setting")
    original_site_title = SiteSetting.title
    expect_usable(
      rpc(
        update_setting,
        data.resolve(
          McpContentRestrictionsUnit2::FIXTURES.fetch("tool:discourse_update_site_setting").fetch(
            "arguments",
          ),
        ),
      ),
    )
    expect(SiteSetting.title).to eq(original_site_title)
    expect(Topic.with_deleted.exists?(id: McpContentRestrictionsUnit2::MISSING_ID)).to eq(false)
    expect(Post.with_deleted.exists?(id: McpContentRestrictionsUnit2::MISSING_ID)).to eq(false)
  end

  it "[cr-u2] requires an explicit fixture and availability row for every live registered primitive" do
    live = DiscourseMcp.registry.all
    expect(live).to be_present
    missing =
      live.map { |primitive| primitive_key(primitive) } - McpContentRestrictionsUnit2::FIXTURES.keys
    expect(missing).to eq([]), "Missing fixtures: #{missing.join(", ")}"
    if ENV["LOAD_PLUGINS"] == "1"
      expect(live.map(&:provider).uniq).to include(
        "chat",
        "discourse-data-explorer",
        "discourse-events",
        "discourse-reactions",
        "discourse-solved",
        "discourse-topic-voting",
      )
    end
    live.each do |primitive|
      fixture = McpContentRestrictionsUnit2::FIXTURES.fetch(primitive_key(primitive))
      expect(fixture.fetch("availability").keys).to match_array(
        McpContentRestrictionsUnit2::CONFIGURATIONS,
      )
      expect(fixture.fetch("availability").values).to all(be_in(%w[usable blocked]))
      id_keys = schema_identifier_fields(primitive.input_schema)
      expect_fixture_id_fields(fixture, id_keys)
      fixture
        .fetch("ids")
        .each_value do |classification|
          expect(classification.keys).to satisfy { |keys|
            keys == ["target"] || keys == ["unrestricted"]
          }
          expect(classification.values.sole).to be_present
        end
    end
  end

  # rubocop:disable Discourse/NoIterationOverRSpecDefinitions
  McpContentRestrictionsUnit2::CONFIGURATIONS.each do |configuration|
    it "[cr-u2] #{configuration} has the expected availability and clean output for every primitive" do
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      data = McpContentRestrictionsUnit2::CanaryData.new(admin, configuration)
      add_redirect_canary(data)
      data.install_rule!
      token
      aggregate_failures(configuration) do
        McpContentRestrictionsUnit2::FIXTURES.each do |key, fixture|
          aggregate_failures("#{configuration} #{key}") do
            ActiveRecord::Base.transaction(requires_new: true) do
              probe_primitive(data, key, fixture)
              raise ActiveRecord::Rollback
            end
          end
        end
      end
    ensure
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      RSpec.configuration.reporter.message("[cr-u2] #{configuration}: #{elapsed.round(2)}s")
    end
  end
  # rubocop:enable Discourse/NoIterationOverRSpecDefinitions
end
