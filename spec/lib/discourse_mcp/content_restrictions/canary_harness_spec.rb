# frozen_string_literal: true

require "active_support/all"
require "securerandom"
require_relative "canary_data"
require_relative "canary_assertions"
require_relative "../../../../lib/text_sentinel"

describe McpContentCanaries do
  include McpContentCanaries::Assertions

  before do
    unless defined?(SiteSetting)
      stub_harness_constant(
        "SiteSetting",
        Struct.new(
          :default_locale,
          :title_max_word_length,
          :title_min_entropy,
          :min_topic_title_length,
          :allow_uppercase_posts,
          :body_min_entropy,
          :min_post_length,
          :min_personal_message_post_length,
        ).new("en", 30, 10, 15, false, 7, 20, 10),
      )
    end
  end

  it "harness: accepts primitives without identifier arguments while still requiring declared identifiers" do
    expect_fixture_id_fields({ "ids" => {} }, [])
    expect do expect_fixture_id_fields({ "ids" => {} }, ["post_id"]) end.to raise_error(
      RSpec::Expectations::ExpectationNotMetError,
    )
  end

  it "harness: accepts a substantive no-cooking reason without requiring a prose prefix" do
    inventory = JSON.parse(File.read(File.join(__dir__, "enrichment_inventory.json")))
    inventory
      .fetch("operations")
      .each { |operation| expect_no_cooking(operation) if operation.fetch("paths").empty? }
    expect do
      expect_no_cooking({ "cooks_nothing" => false, "raw" => "No raw is cooked" })
    end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
  end

  it "harness: seeds unique titles and raw that satisfy the normal text quality and length limits" do
    data = McpContentCanaries::CanaryData.allocate
    {
      admin: Object.new,
      allowed: Object.new,
      recipient: Object.new,
      serial: 0,
      tokens: {
      },
      posts: {
      },
    }.each { |name, value| data.instance_variable_set("@#{name}", value) }
    titles = []
    raws = []
    allow(data).to receive(:Fabricate) do |kind, **attributes|
      if kind == :post
        raws << attributes.fetch(:raw)
      else
        titles << attributes.fetch(:title)
      end
      Object.new
    end
    %i[
      outside_allowlist
      denied_subcategory
      tagged_after_index
      tagged_definition
      restricted_author
      membership_request
      reviewable_conversation
      redirect_target
    ].each { |name| data.send(:add_post, name) }
    data.send(:add_post, :private_message, private_message: true)
    expect(titles.uniq.size).to eq(titles.size)
    expect(raws.uniq.size).to eq(raws.size)
    titles.each_with_index do |title, index|
      expect(title).to include(data.tokens.values.fetch(index))
      expect(title.length).to be_between(15, 255)
      expect(TextSentinel.title_sentinel(title).valid?).to eq(true), title
    end
    raws.each do |raw|
      expect(raw.length).to be_between(20, 32_000)
      expect(TextSentinel.body_sentinel(raw).valid?).to eq(true), raw
      expect(TextSentinel.body_sentinel(raw, private_message: true).valid?).to eq(true), raw
    end
  end

  it "harness: keeps literal request titles and post bodies above normal minimums with distinct titles" do
    titles = []
    McpContentCanaries::FIXTURES.each_value do |fixture|
      fixture
        .fetch("arguments")
        .each do |field, value|
          next unless %w[title raw reply].include?(field) && value.is_a?(String)
          next if value.start_with?("$")
          if field == "title"
            titles << value
            expect(value.length).to be_between(15, 255)
            expect(TextSentinel.new(value, min_entropy: 10, max_word_length: 30).valid?).to eq(
              true,
            ),
            value
          else
            expect(value.length).to be_between(20, 32_000)
            expect(TextSentinel.new(value, min_entropy: 7).valid?).to eq(true), value
          end
        end
    end
    expect(titles.uniq.size).to eq(titles.size)
  end

  it "harness: applies the fixture availability rules without consulting live declarations" do
    fixtures = McpContentCanaries::FIXTURES
    always_blocked =
      %w[
        discourse_create_webhook
        discourse_update_webhook
        discourse_redeliver_webhook_event
        discourse_update_site_setting
        discourse_set_theme_code
        discourse_create_theme
        discourse_update_theme
        discourse_delete_theme
        discourse_install_theme
        discourse_sync_remote_theme
        discourse_upload_theme_asset
        discourse_update_theme_setting
        discourse_update_theme_translations
        chat_channel_list
        discourse_get_chat_messages
        chat_message_create
        discourse_run_query
      ].map { |identifier| "tool:#{identifier}" }
    pm_blocked =
      %w[
        discourse_list_private_messages
        discourse_read_private_message
        discourse_create_private_message
        discourse_reply_private_message
        discourse_invite_to_private_message
        discourse_handle_group_membership_request
      ].map { |identifier| "tool:#{identifier}" }
    forum_blocked =
      %w[
        discourse_create_tag_group
        discourse_update_tag_group
        discourse_delete_tag_group
      ].map { |identifier| "tool:#{identifier}" }
    McpContentCanaries::CONFIGURATIONS.each do |configuration|
      expected = always_blocked.dup
      expected.concat(pm_blocked) if %w[pm_off pm_off_and_forum].include?(configuration)
      expected.concat(forum_blocked) unless configuration == "pm_off"
      actual =
        fixtures
          .select { |_, fixture| fixture.fetch("availability").fetch(configuration) == "blocked" }
          .keys
      expect(actual).to match_array(expected), configuration
    end
    fixtures.each_value { |fixture| expect(fixture.fetch("availability_rule")).to be_present }
  end

  it "harness: requires exact blocked protocol or tool responses and rejects unrelated failures" do
    message = "This capability is turned off by the site's AI content restrictions"
    allow(I18n).to receive(:t).with("mcp.errors.content_policy_blocked").and_return(message)
    response = {
      "status" => 400,
      "headers" => {
      },
      "body" => {
        "jsonrpc" => "2.0",
        "id" => 1,
        "error" => {
          "code" => -32_602,
          "message" => message,
        },
      },
    }
    expect_blocked(response, server_version: "test")
    tool_response = {
      "status" => 200,
      "headers" => {
      },
      "body" => {
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => {
          "content" => [{ "type" => "text", "text" => message }],
          "isError" => true,
          "resultType" => "complete",
          "_meta" => {
            "io.modelcontextprotocol/serverInfo" => {
              "name" => "discourse",
              "version" => "test",
            },
          },
        },
      },
    }
    expect_blocked(tool_response, server_version: "test")
    [
      tool_response.deep_merge("body" => { "result" => { "isError" => false } }),
      tool_response.deep_merge(
        "body" => {
          "result" => {
            "structuredContent" => {
              "raw" => "extra leaked text",
            },
          },
        },
      ),
      response.merge("status" => 200),
      response.merge("status" => 500),
      response.deep_merge("headers" => { "WWW-Authenticate" => "Bearer" }),
      response.deep_merge("body" => { "error" => { "code" => -32_603 } }),
      response.deep_merge("body" => { "error" => { "message" => "Unrelated error" } }),
      response.deep_merge("body" => { "result" => { "content" => "extra leaked text" } }),
    ].each do |invalid|
      expect { expect_blocked(invalid, server_version: "test") }.to raise_error(
        RSpec::Expectations::ExpectationNotMetError,
      )
    end
  end

  def stub_harness_constant(name, value)
    RSpec::Mocks::ExampleMethods.instance_method(:stub_const).bind_call(self, name, value)
  end

  def capture_seed(configuration, plugins: false)
    calls = []
    existing_categories = [
      double(id: 1, name: "Uncategorized", slug: "uncategorized", description: nil),
      double(id: 2, name: "Existing category", slug: "existing-category", description: nil),
    ]
    categories = double
    allow(categories).to receive(:to_a) do
      existing_categories +
        calls.filter_map do |kind, _, record|
          record if %i[category category_with_definition].include?(kind)
        end
    end
    stub_harness_constant("Category", double(all: categories, reset_voting_cache: nil))
    stub_harness_constant("SearchIndexer", double(index: nil))
    stub_harness_constant("TopicAllowedUser", double(find_or_create_by!: nil))
    stub_harness_constant("UploadReference", double(create!: nil))
    stub_harness_constant("Tag", double(update_topic_counts: nil))
    stub_harness_constant("UserAction::REPLY", 5)
    if plugins
      stub_harness_constant("DiscourseTopicVoting::CategorySetting", double(create!: nil))
      stub_harness_constant("DiscourseDataExplorer::Query", double(create!: double(id: 101)))
      stub_harness_constant("Chat::Channel", Class.new)
    else
      hide_const("DiscourseTopicVoting::CategorySetting")
      hide_const("DiscourseDataExplorer::Query")
      hide_const("Chat::Channel")
    end
    stub_harness_constant("DiscourseMcp::Tools::ThemeSupport", double(code_revision: "revision"))
    allow(I18n).to receive(:t) do |key, **options|
      expect(key).to eq("groups.request_membership_pm.title")
      expect(options.fetch(:group_name)).to be_present
      expect(options.fetch(:locale)).to eq("en")
      "A request to join the fixture group"
    end
    allow(SiteSetting).to receive(:title).and_return("Forum")
    data = McpContentCanaries::CanaryData.allocate
    unless defined?(Discourse)
      stub_harness_constant("Discourse", double(base_url: "https://example.com"))
    end
    allow(data).to receive(:Fabricate) do |kind, **attributes|
      tags = []
      tag_association = double
      allow(tag_association).to receive(:<<) { |tag| tags << tag }
      allow(tag_association).to receive(:exists?) { |id:| tags.any? { |tag| tag.id == id } }
      record =
        double(
          id: attributes.fetch(:id, 90_000_000 + calls.length + 1),
          name: attributes.fetch(:name, "Fixture #{calls.length}"),
          slug: attributes.fetch(:name, "Fixture #{calls.length}").parameterize,
          description: attributes[:description],
          parent_category_id: attributes[:parent_category]&.id,
          username: "fixture#{calls.length}",
          email: "fixture#{calls.length}@example.com",
          url: "/fixtures/#{calls.length}",
          relative_url: "/fixtures/#{calls.length}",
          short_url: "upload://fixture#{calls.length}",
          effective_locale: "en",
          destination_fingerprint: "fingerprint",
          tags: tag_association,
          custom_fields: {
          },
          reviewable_scores: [double(update!: true)],
          category: attributes[:category],
          category_id: attributes[:category]&.id,
          private_message?: kind == :private_message_topic,
        ).as_null_object
      if kind == :post
        allow(record).to receive_messages(
          topic: attributes.fetch(:topic),
          topic_id: attributes.fetch(:topic).id,
          user: attributes.fetch(:user),
          raw: attributes.fetch(:raw, "Hello world"),
          cooked: "<p>Fixture body</p>",
          full_url: "https://example.com/t/#{attributes.fetch(:topic).id}",
        )
      end
      calls << [kind, attributes, record]
      record
    end
    data.send(:initialize, double(username: "admin"), configuration)
    [data, calls]
  end

  it "harness: supplies distinct draft keys and serialized data for every seeded topic" do
    configurations = McpContentCanaries::CONFIGURATIONS + ["pm_off"]
    configurations.each do |configuration|
      data, calls = capture_seed(configuration)
      drafts = calls.select { |kind, _, _| kind == :draft }
      expect(drafts.size).to eq(data.posts.size + 1)
      keys = drafts.map { |_, attributes, _| attributes.fetch(:draft_key) }
      expect(keys.uniq.size).to eq(drafts.size)
      drafts.each do |_, attributes, _|
        expect(attributes.fetch(:draft_key)).to eq("topic_#{attributes.fetch(:topic).id}")
        expect(attributes.fetch(:sequence)).to eq(0)
        expect(JSON.parse(attributes.fetch(:data)).fetch("reply")).to be_present
      end
      expect(keys).to include(data.values.fetch("draft_key"))
      expect(data.values.keys).not_to include("channel_id", "query_id")
    end
  end

  it "harness: resolves plugin identifiers only when the corresponding models are loaded" do
    data, calls = capture_seed("pm_off", plugins: true)
    channel = calls.find { |kind, _, _| kind == :category_channel }.last
    expect(data.resolve("$channel_id")).to eq(channel.id)
    expect(data.resolve("$query_id")).to eq(101)
  end

  it "harness: treats every category outside the selected subtrees as restricted, including empty and existing categories" do
    data, calls = capture_seed("allowlist")
    permitted_ids = data.forum_config.fetch(:allow).fetch(:category_ids)
    empty = calls.find { |_, _, record| record.id == data.values.fetch("empty_category_id") }.last
    permitted_ids << empty.id if permitted_ids.include?(empty.parent_category_id)
    categories = Category.all.to_a
    excluded = categories.reject { |category| permitted_ids.include?(category.id) }
    expect(data.targets("category")).to match_array(
      excluded.map { |category| [category.id, McpContentCanaries::MISSING_ID] },
    )
    expect(data.targets("categories")).to match_array(
      excluded.map { |category| [[category.id], [McpContentCanaries::MISSING_ID]] },
    )
    expect(data.restricted_ids & categories.map(&:id)).to match_array(excluded.map(&:id))
    excluded.each do |category|
      [category.name, category.slug, category.description].compact_blank.each do |text|
        expect { expect_clean(draft_response("unrelated", category: text), data) }.to raise_error(
          RSpec::Expectations::ExpectationNotMetError,
        ),
        text
      end
    end
  end

  it "harness: uses permitted targets for every category-bearing usable fixture under the allowlist" do
    data, calls = capture_seed("allowlist")
    allowed_ids = data.forum_config.fetch(:allow).fetch(:category_ids)
    empty = calls.find { |_, _, record| record.id == data.values.fetch("empty_category_id") }.last
    expect(allowed_ids).to include(empty.parent_category_id)
    expect(data.targets("category").map(&:first)).not_to include(empty.id)
    McpContentCanaries::FIXTURES.each do |key, fixture|
      next unless fixture.fetch("availability").fetch("allowlist") == "usable"
      arguments = fixture.fetch("arguments")
      fixture
        .fetch("ids")
        .each do |field, classification|
          next if %w[category categories].exclude?(classification["target"])
          next unless arguments.key?(field)
          Array(data.resolve(arguments.fetch(field))).each do |id|
            expect(allowed_ids + [empty.id]).to include(id), "#{key} #{field}"
          end
        end
      if key == "tool:discourse_create_category"
        expect(data.resolve(arguments.fetch("parent_category_id", nil))).to be_in(allowed_ids)
      end
    end
  end

  it "harness: catches restricted ancestor ids side-loaded with an allowed topic" do
    data, = capture_seed("allowlist")
    category = data.allowed_post.topic.category
    expect(data.forum_config.fetch(:allow).fetch(:category_ids)).to include(category.id)
    expect(category.parent_category_id).to be_present
    expect(data.targets("category").map(&:first)).to include(category.parent_category_id)
    expect_clean(
      draft_response("unrelated", topic_id: data.allowed_post.topic_id, category_id: category.id),
      data,
    )
    [
      { parent_category_id: category.parent_category_id },
      { category_ids: [category.id, category.parent_category_id] },
      { categories: [{ id: category.id, parent_category_id: category.parent_category_id }] },
      { categories: [{ id: category.parent_category_id }] },
    ].each do |leak|
      expect do
        expect_clean(
          draft_response("unrelated", topic_id: data.allowed_post.topic_id, **leak),
          data,
        )
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError),
      leak.inspect
    end
  end

  it "harness: distinguishes existing category ids from protocol ids and counters while scanning every category surface" do
    data, = capture_seed("allowlist")
    category = Category.all.to_a.find { |record| record.name == "Uncategorized" }
    expect(data.restricted_ids).to include(category.id)
    clean = draft_response("unrelated", topic_id: data.allowed_post.topic_id, count: category.id)
    clean["body"]["id"] = category.id
    expect_clean(clean, data)
    [
      { category_id: category.id },
      { parent_category_id: category.id },
      { category_ids: [data.allowed_post.topic.category_id, category.id] },
      { categories: [{ id: category.id }] },
      { category: { id: category.id } },
      { categories: { category.id.to_s => { name: "Redacted" } } },
    ].each do |leak|
      response = draft_response("unrelated", **leak)
      json_text = response.dig("body", "result", "content", 0, "text")
      [
        response,
        response.deep_dup.tap { |copy| copy["body"]["result"].delete("structuredContent") },
        response.deep_dup.tap { |copy| copy["body"]["result"].delete("content") },
        {
          "status" => 200,
          "headers" => {
          },
          "body" => {
            "result" => {
              "contents" => [{ "text" => json_text }],
            },
          },
        },
        {
          "status" => 200,
          "headers" => {
          },
          "body" => {
            "result" => {
              "messages" => [{ "content" => { "text" => json_text } }],
            },
          },
        },
        { "status" => 200, "headers" => {}, "body" => { "error" => leak } },
        { "status" => 200, "headers" => { "X-Category-Id" => category.id.to_s }, "body" => {} },
      ].each do |surface|
        expect { expect_clean(surface, data) }.to raise_error(
          RSpec::Expectations::ExpectationNotMetError,
        ),
        surface.inspect
      end
    end
  end

  it "harness: classifies nested tag selectors and theme field identifiers" do
    %w[discourse_create_tag_group discourse_update_tag_group].each do |identifier|
      expect_fixture_id_fields(
        McpContentCanaries::FIXTURES.fetch("tool:#{identifier}"),
        %w[tags[].id parent_tag.id],
      )
    end
    %w[discourse_create_theme discourse_update_theme].each do |identifier|
      expect_fixture_id_fields(
        McpContentCanaries::FIXTURES.fetch("tool:#{identifier}"),
        %w[theme_fields[].type_id theme_fields[].upload_id],
      )
    end
  end

  it "harness: discovers identifiers through array items and schema alternatives" do
    selector = {
      "oneOf" => [
        { "properties" => { "id" => { "type" => "integer" } } },
        { "properties" => { "name" => { "type" => "string" } } },
      ],
    }
    schema = {
      "properties" => {
        "tag_group_id" => {
          "type" => "integer",
        },
        "tags" => {
          "items" => selector,
        },
        "parent_tag" => {
          "anyOf" => [selector, { "type" => "null" }],
        },
      },
      "allOf" => [{ "properties" => { "post_ids" => { "type" => "array" } } }],
    }
    expect(schema_identifier_fields(schema)).to contain_exactly(
      "tag_group_id",
      "tags[].id",
      "parent_tag.id",
      "post_ids",
    )
  end

  it "harness: replaces nested identifiers while preserving valid siblings and original arguments" do
    fixture = McpContentCanaries::FIXTURES.fetch("tool:discourse_update_theme")
    arguments = { "theme_id" => 42, "name" => "Preserved theme" }
    expect(arguments_with_identifier(arguments, fixture, "theme_fields[].upload_id", 123)).to eq(
      "theme_id" => 42,
      "name" => "Preserved theme",
      "theme_fields" => [
        {
          "name" => "cr_u2_asset",
          "target" => "common",
          "type" => "theme_upload_var",
          "upload_id" => 123,
        },
      ],
    )
    expect(arguments).to eq("theme_id" => 42, "name" => "Preserved theme")
    expect(arguments_with_identifier(arguments, {}, "tags[].id", 123)).to eq(
      arguments.merge("tags" => [{ "id" => 123 }]),
    )
    expect(arguments_with_identifier(arguments, {}, "parent_tag.id", 123)).to eq(
      arguments.merge("parent_tag" => { "id" => 123 }),
    )
    expect(arguments_with_identifier(arguments, {}, "theme_id", 123)).to eq(
      arguments.merge("theme_id" => 123),
    )
  end

  def draft_response(key, **extra)
    value = { "draft_key" => key, "found" => false }.merge(extra.stringify_keys)
    {
      "status" => 200,
      "headers" => {
      },
      "body" => {
        "result" => {
          "content" => [{ "type" => "text", "text" => JSON.generate(value) }],
          "structuredContent" => value,
          "isError" => false,
        },
      },
    }
  end

  it "harness: detects every restricted canary in normalized titles, slugs and excerpts" do
    covered_names = []
    seeded_names = []
    McpContentCanaries::CONFIGURATIONS.each do |configuration|
      data, = capture_seed(configuration)
      seeded_names |= data.posts.keys
      covered_names |=
        data.posts.keys.select { |name| data.restricted_tokens.include?(data.tokens.fetch(name)) }
      expect(data.restricted_tokens).to include(data.tokens.fetch(:redirect_target))
      restrictions =
        Struct.new(
          :restricted_tokens,
          :restricted_urls,
          :restricted_ids,
          :restricted_category_text,
          :contextual_category_ids,
        ).new(data.restricted_tokens, [], [], [], [])
      data.restricted_tokens.each do |token_value|
        marker = token_value.split.last
        variants = [
          token_value,
          token_value.upcase,
          token_value.capitalize,
          token_value.tr(" ", "-"),
          token_value.tr(" ", "_"),
          token_value.gsub(" ", "\u00a0"),
          token_value.gsub(" ", "<em> </em>"),
          token_value.gsub(" ", "&#32;"),
          marker.upcase,
          marker.chars.join("-"),
          marker.chars.map { |character| "&##{character.ord};" }.join,
          marker.chars.map { |character| (character.ord + 0xfee0).chr(Encoding::UTF_8) }.join,
        ]
        variants.each do |variant|
          %w[title slug excerpt].each do |field|
            response = { "status" => 200, "headers" => {}, "body" => { field => variant } }
            expect { expect_clean(response, restrictions) }.to raise_error(
              RSpec::Expectations::ExpectationNotMetError,
            ),
            "#{configuration} #{field}: #{variant.inspect} escaped detection for #{token_value.inspect}"
          end
        end
      end
      (data.tokens.values - data.restricted_tokens).each do |allowed_token|
        expect_clean(draft_response("unrelated", title: allowed_token.upcase), restrictions)
      end
    end
    expect(covered_names).to match_array(seeded_names)
  end

  it "harness: scans each response surface and decodes JSON text before matching tokens" do
    data, = capture_seed("pm_off")
    token_value = data.tokens.fetch(:redirect_target)
    restrictions =
      Struct.new(
        :restricted_tokens,
        :restricted_urls,
        :restricted_ids,
        :restricted_category_text,
        :contextual_category_ids,
      ).new([token_value], [], [], [], [])
    marker = token_value.split.last
    fullwidth = marker.chars.map { |character| (character.ord + 0xfee0).chr(Encoding::UTF_8) }.join
    escaped = JSON.generate({ "title" => fullwidth }, ascii_only: true)
    [
      { "headers" => { "X-Canary" => token_value.upcase } },
      { "body" => { "error" => { "message" => token_value.upcase } } },
      {
        "body" => {
          "result" => {
            "structuredContent" => {
              "slug" => token_value.tr(" ", "-"),
            },
          },
        },
      },
      { "body" => { "result" => { "content" => [{ "type" => "text", "text" => escaped }] } } },
      { "body" => { "result" => { "contents" => [{ "text" => escaped }] } } },
      { "body" => { "result" => { "messages" => [{ "content" => { "text" => escaped } }] } } },
    ].each do |surface|
      response = { "status" => 200, "headers" => {}, "body" => {} }.merge(surface)
      expect { expect_clean(response, restrictions) }.to raise_error(
        RSpec::Expectations::ExpectationNotMetError,
      ),
      surface.inspect
    end
  end

  it "harness: attributes a single restricted-output failure to its matrix cell" do
    data, = capture_seed("pm_off")
    response = draft_response("unrelated", title: data.tokens.fetch(:redirect_target))
    restrictions =
      Struct.new(
        :restricted_tokens,
        :restricted_urls,
        :restricted_ids,
        :restricted_category_text,
        :contextual_category_ids,
      ).new([data.tokens.fetch(:redirect_target)], [], [], [], [])
    label = "pm_off tool:discourse_get_user_summary"
    expect do
      aggregate_failures("pm_off") do
        aggregate_failures(label) { expect_clean(response, restrictions, cell: label) }
      end
    end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /#{Regexp.escape(label)}/)
  end

  it "harness: substitutes only an exact caller echo in the declared structured and text fields" do
    response = draft_response("topic_92000001")
    normalized =
      response_without_request_echo(
        response,
        field: "draft_key",
        supplied: "topic_92000001",
        replacement: "topic_99999999",
        echoes: {
          "draft_key" => [
            %w[body result structuredContent draft_key],
            ["body", "result", "content", 0, "text", "draft_key"],
          ],
        },
      )
    expect(normalized).to eq(draft_response("topic_99999999"))
    expect(response).to eq(draft_response("topic_92000001"))
  end

  it "harness: preserves whitespace and unrelated text bytes when substituting a JSON echo" do
    response = draft_response("topic_92000001")
    text = response.fetch("body").fetch("result").fetch("content").first
    text["text"] = '{ "found" : false, "draft_key" : "topic_92000001" }'
    normalized =
      response_without_request_echo(
        response,
        field: "draft_key",
        supplied: "topic_92000001",
        replacement: "topic_99999999",
        echoes:
          McpContentCanaries::FIXTURES.fetch("tool:discourse_get_draft").fetch("request_echoes"),
      )
    expect(normalized.dig("body", "result", "content", 0, "text")).to eq(
      text.fetch("text").sub("topic_92000001", "topic_99999999"),
    )
    expect(normalized).not_to eq(draft_response("topic_99999999"))
    expect(
      response_without_request_echo(
        response,
        field: "post_id",
        supplied: "topic_92000001",
        replacement: "topic_99999999",
        echoes: {
        },
      ),
    ).to eq(response)
  end

  it "harness: preserves every extra leak, including a second identifier inside the echo value" do
    fixture = McpContentCanaries::FIXTURES.fetch("tool:discourse_get_draft")
    [
      draft_response("topic_92000001", topic_id: 92_000_001),
      draft_response("topic_92000001", data: { "draft_key" => "topic_92000001" }),
      draft_response("topic_92000001 topic_92000002"),
    ].each do |response|
      normalized =
        response_without_request_echo(
          response,
          field: "draft_key",
          supplied: "topic_92000001",
          replacement: "topic_99999999",
          echoes: fixture.fetch("request_echoes", {}),
        )
      expect(JSON.generate(normalized)).to include("9200000")
      expect(normalized).not_to eq(draft_response("topic_99999999"))
    end
  end
end
