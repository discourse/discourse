# frozen_string_literal: true

describe DiscourseMcp::Server do
  describe "get_user_summary bookmark counts" do
    fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
    let(:client) do
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Bookmark count client",
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
    let(:raw_token) { McpOauthAccessToken.issue!(authorization:) }
    let(:token) { McpOauthAccessToken.find_by!(token_hash: McpOauthAccessToken.digest(raw_token)) }

    before do
      DiscourseMcp.reset_registry!
      SiteSetting.mcp_server_enabled = true
      SiteSetting.secure_uploads = false
      SiteSetting.uploaded_avatars_allowed_groups = Group::AUTO_GROUPS[:everyone]
    end

    around do |example|
      original_registry = DiscourseMcp.registry
      example.run
    ensure
      DiscourseMcp.instance_variable_set(:@registry, original_registry)
    end

    def activate_rule(kind)
      return McpContentRule.create!(rule_kind: "private_messages", config: {}) if kind == "PM-off"

      DiscourseMcp.registry.register_content_data_kind("oracle:metadata", provider: "oracle")
      DiscourseMcp.registry.register_content_rule_kind(
        "oracle:metadata",
        provider: "oracle",
        affected_data_kinds: ["oracle:metadata"],
        config_contract: {
          type: "object",
          additionalProperties: false,
        },
        compile: ->(_config) { DiscourseMcp::ContentPolicy::Evaluator.new },
      )
      McpContentRule.create!(rule_kind: "oracle:metadata", config: {})
      expect(DiscourseMcp::ContentPolicy.load).to be_active
      expect(DiscourseMcp::ContentPolicy.load.denies_all?("private_messages")).to eq(false)
    end

    def tool(name, arguments = {})
      McpPrimitive.find_or_create_by!(kind: "tool", identifier: name).update!(enabled: true)
      expect(DiscourseMcp.registry.find(:tool, name)).to be_present
      request = ActionDispatch::TestRequest.create
      request.headers["MCP-Protocol-Version"] = DiscourseMcp::LEGACY_PROTOCOL_VERSION
      DiscourseMcp::Server.new(
        request:,
        request_context: DiscourseMcp::RequestContext.new(token),
      ).call(
        {
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => {
            "name" => name,
            "arguments" => arguments.deep_stringify_keys,
          },
        },
      )
    end

    def content(response)
      expect(response.http_status).to eq(200)
      expect(response.body[:error]).to be_nil
      expect(response.body.dig(:result, :isError)).to eq(false)
      structured = response.body.fetch(:result).fetch(:structuredContent).deep_symbolize_keys
      text = response.body.fetch(:result).fetch(:content).sole.fetch(:text)
      expect(JSON.parse(text, symbolize_names: true)).to eq(structured)
      structured
    end

    def expect_blocked(response)
      expect(response.http_status).to eq(200)
      expect(response.body[:error]).to be_nil
      expect(response.body.dig(:result, :isError)).to eq(true)
      expect(response.body.dig(:result, :content)).to eq(
        [{ type: "text", text: I18n.t("mcp.errors.content_policy_blocked") }],
      )
      expect(response.body.dig(:result, :structuredContent)).to be_nil
      expect(response.headers.keys.map(&:downcase)).not_to include("www-authenticate")
    end

    shared_examples "PM bookmark summary counts" do |bookmark_type|
      it "excludes a sole PM #{bookmark_type} bookmark from get_user_summary under PM-off" do
        message = Fabricate(:private_message_post, user: admin)
        bookmarkable = bookmark_type == :topic ? message.topic : message
        Fabricate(:bookmark, user: admin, bookmarkable:)
        Fabricate(:topic_user, user: admin, topic: message.topic)
        expect(
          content(tool("discourse_get_user_summary", username: admin.username)).fetch(
            :bookmark_count,
          ),
        ).to eq(1)
        activate_rule("PM-off")

        result = content(tool("discourse_get_user_summary", username: admin.username))

        expect(result.fetch(:bookmark_count)).to eq(0)
      end

      it "counts a sole PM #{bookmark_type} bookmark in get_user_summary without rule rows" do
        message = Fabricate(:private_message_post, user: admin)
        bookmarkable = bookmark_type == :topic ? message.topic : message
        Fabricate(:bookmark, user: admin, bookmarkable:)
        Fabricate(:topic_user, user: admin, topic: message.topic)

        result = content(tool("discourse_get_user_summary", username: admin.username))

        expect(result.fetch(:bookmark_count)).to eq(1)
      end
    end

    include_examples "PM bookmark summary counts", :topic
    include_examples "PM bookmark summary counts", :post

    it "retains public topic and post bookmarks while excluding both PM bookmark types under PM-off" do
      message = Fabricate(:private_message_post, user: admin)
      public_post = Fabricate(:post, user: admin)
      [message.topic, message, public_post.topic, public_post].each do |bookmarkable|
        Fabricate(:bookmark, user: admin, bookmarkable:)
      end
      Fabricate(:topic_user, user: admin, topic: message.topic)
      Fabricate(:topic_user, user: admin, topic: public_post.topic)
      expect(
        content(tool("discourse_get_user_summary", username: admin.username)).fetch(
          :bookmark_count,
        ),
      ).to eq(4)
      activate_rule("PM-off")

      result = content(tool("discourse_get_user_summary", username: admin.username))

      expect(result.fetch(:bookmark_count)).to eq(2)
    end
  end

  describe "get_user_summary and directory metrics" do
    fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
    let(:client) do
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "User metrics client",
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
    let(:raw_token) { McpOauthAccessToken.issue!(authorization:) }
    let(:token) { McpOauthAccessToken.find_by!(token_hash: McpOauthAccessToken.digest(raw_token)) }

    before do
      DiscourseMcp.reset_registry!
      SiteSetting.mcp_server_enabled = true
      SiteSetting.secure_uploads = false
      SiteSetting.enable_badges = false
    end

    around do |example|
      original_registry = DiscourseMcp.registry
      example.run
    ensure
      DiscourseMcp.instance_variable_set(:@registry, original_registry)
    end

    def activate_rule(kind)
      if kind == "without rule rows"
        expect(McpContentRule.count).to eq(0)
        return
      end
      return McpContentRule.create!(rule_kind: "private_messages", config: {}) if kind == "PM-off"

      DiscourseMcp.registry.register_content_data_kind("oracle:metadata", provider: "oracle")
      DiscourseMcp.registry.register_content_rule_kind(
        "oracle:metadata",
        provider: "oracle",
        affected_data_kinds: ["oracle:metadata"],
        config_contract: {
          type: "object",
          additionalProperties: false,
        },
        compile: ->(_config) { DiscourseMcp::ContentPolicy::Evaluator.new },
      )
      McpContentRule.create!(rule_kind: "oracle:metadata", config: {})
      expect(DiscourseMcp::ContentPolicy.load).to be_active
      expect(DiscourseMcp::ContentPolicy.load.denies_all?("private_messages")).to eq(false)
    end

    def tool(name, arguments = {})
      McpPrimitive.find_or_create_by!(kind: "tool", identifier: name).update!(enabled: true)
      expect(DiscourseMcp.registry.find(:tool, name)).to be_present
      request = ActionDispatch::TestRequest.create
      request.headers["MCP-Protocol-Version"] = DiscourseMcp::LEGACY_PROTOCOL_VERSION
      DiscourseMcp::Server.new(
        request:,
        request_context: DiscourseMcp::RequestContext.new(token),
      ).call(
        {
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => {
            "name" => name,
            "arguments" => arguments.deep_stringify_keys,
          },
        },
      )
    end

    def content(response)
      expect(response.http_status).to eq(200)
      expect(response.body[:error]).to be_nil
      expect(response.body.dig(:result, :isError)).to eq(false)
      structured = response.body.fetch(:result).fetch(:structuredContent).deep_symbolize_keys
      text = response.body.fetch(:result).fetch(:content).sole.fetch(:text)
      expect(JSON.parse(text, symbolize_names: true)).to eq(
        JSON.parse(JSON.generate(structured), symbolize_names: true),
      )
      structured
    end

    def expect_blocked(response)
      expect(response.http_status).to eq(200)
      expect(response.body[:error]).to be_nil
      expect(response.body.dig(:result, :isError)).to eq(true)
      expect(response.body.dig(:result, :content)).to eq(
        [{ type: "text", text: I18n.t("mcp.errors.content_policy_blocked") }],
      )
      expect(response.body.dig(:result, :structuredContent)).to be_nil
      expect(response.headers.keys.map(&:downcase)).not_to include("www-authenticate")
    end

    shared_examples "summary metrics" do |kind|
      it "filters all eight unsafe get_user_summary metrics and preserves bookmarks #{kind}" do
        public_post = Fabricate(:post, user: admin, topic: Fabricate(:topic, user: admin))
        public_reply = Fabricate(:post, user: admin, topic: public_post.topic)
        message = Fabricate(:private_message_post, user: admin)
        [public_post, public_post.topic, message, message.topic].each do |bookmarkable|
          Fabricate(:bookmark, user: admin, bookmarkable:)
        end
        Fabricate(:topic_user, user: admin, topic: public_post.topic)
        Fabricate(:topic_user, user: admin, topic: message.topic)
        # Aggregate snapshots can retain PM contributions until their next consistency pass.
        metrics = {
          likes_given: 11,
          likes_received: 13,
          topics_entered: 17,
          posts_read_count: 19,
          time_read: 23,
          topic_count: 29,
          post_count: 31,
        }
        admin.user_stat.update!(**metrics, days_visited: 7)
        Fabricate(:user_visit, user: admin, visited_at: Date.current, time_read: 5)
        metrics[:recent_time_read] = 5
        native = content(tool("discourse_get_user_summary", username: admin.username))
        expect(native).to include(**metrics, bookmark_count: 4, days_visited: 7)
        activate_rule(kind)

        result = content(tool("discourse_get_user_summary", username: admin.username))

        if kind == "PM-off"
          expect(result.slice(*metrics.keys).compact).to be_empty
          expect(result).to include(bookmark_count: 2, days_visited: 7)
          expect(result.fetch(:top_replies).pluck(:post_number)).to include(
            public_reply.post_number,
          )
        else
          expect(result).to eq(native)
        end
      end

      it "makes a PM-only reader indistinguishable from an inactive summary user #{kind}" do
        freeze_time
        reader = Fabricate(:user, last_seen_at: Time.zone.now)
        inactive = Fabricate(:user, last_seen_at: Time.zone.now)
        message = Fabricate(:private_message_post, recipient: reader)
        DB.exec(
          "INSERT INTO topic_views (topic_id, user_id, viewed_at, ip_address) VALUES (:topic_id, :user_id, :viewed_at, '127.0.0.1')",
          topic_id: message.topic_id,
          user_id: reader.id,
          viewed_at: Date.current,
        )
        PostTiming.record_timing(
          topic_id: message.topic_id,
          user_id: reader.id,
          post_number: message.post_number,
          msecs: 12_000,
        )
        Fabricate(:user_visit, user: reader, visited_at: Date.current)
        UserStat.cache_last_seen(reader.id, 12.seconds.ago.to_f)
        UserStat.update_time_read!(reader.id)
        UserStat.update_view_counts
        expect(reader.posts).to be_empty
        expect(reader.user_stat.reload).to have_attributes(topics_entered: 1, time_read: 12)
        activate_rule(kind)

        active = content(tool("discourse_get_user_summary", username: reader.username))
        idle = content(tool("discourse_get_user_summary", username: inactive.username))

        if kind == "PM-off"
          expect(active.except(:username)).to eq(idle.except(:username))
          expect(
            active.slice(:topics_entered, :posts_read_count, :time_read, :recent_time_read).compact,
          ).to be_empty
        else
          expect(active).to include(topics_entered: 1, time_read: 12, recent_time_read: 12)
          expect(idle).to include(topics_entered: 0, time_read: 0, recent_time_read: 0)
        end
      end
    end

    include_examples "summary metrics", "PM-off"
    include_examples "summary metrics", "an unrelated rule"
    include_examples "summary metrics", "without rule rows"

    def directory_fixture
      SiteSetting.enable_user_directory = true
      DirectoryColumn.automatic_column_names.each_with_index do |name, position|
        DirectoryColumn.find_or_initialize_by(name: name.to_s).update!(
          type: :automatic,
          enabled: true,
          position:,
        )
      end
      group = Fabricate(:group)
      alpha = Fabricate(:user, username: "round2_alpha")
      bravo = Fabricate(:user, username: "round2_bravo")
      [alpha, bravo].each { |user| group.add(user) }
      [alpha, bravo].zip([3, 7], [9, 2])
        .each do |user, safe_value, reading_value|
          user.user_stat.update!(time_read: reading_value * 10)
          %i[all daily].each do |period|
            DirectoryItem.create!(
              user:,
              period_type: DirectoryItem.period_types[period],
              likes_received: safe_value,
              likes_given: safe_value,
              topic_count: safe_value,
              post_count: safe_value,
              days_visited: safe_value,
              topics_entered: reading_value,
              posts_read: reading_value,
            )
          end
        end
      [group, alpha, bravo]
    end

    shared_examples "directory metrics" do |kind|
      it "filters directory reading values while preserving other columns #{kind}" do
        group, alpha, bravo = directory_fixture
        activate_rule(kind)

        %w[all daily].each do |period|
          result = content(tool("discourse_list_directory_items", period:, group: group.name))
          rows = result.fetch(:directory_items)
          expect(rows.pluck(:id)).to eq([bravo.id, alpha.id])
          expect(result.fetch(:meta)).to include(total: 2, returned: 2, has_more: false)
          rows
            .zip([7, 3], [2, 9])
            .each do |row, safe_value, reading_value|
              aggregate_failures("#{period}: #{row.fetch(:id)}") do
                expect(row).to include(
                  likes_received: safe_value,
                  likes_given: safe_value,
                  topic_count: safe_value,
                  post_count: safe_value,
                  days_visited: safe_value,
                )
                if kind == "PM-off"
                  expect(row.slice(:topics_entered, :posts_read, :time_read).compact).to be_empty
                else
                  expect(row).to include(
                    topics_entered: reading_value,
                    posts_read: reading_value,
                    time_read: period == "all" ? reading_value * 10 : nil,
                  )
                end
              end
            end
        end
      end

      it "handles directory ordering by topics_entered #{kind}" do
        group, alpha, bravo = directory_fixture
        activate_rule(kind)

        %w[all daily].each do |period|
          [false, true].each do |ascending|
            response =
              tool(
                "discourse_list_directory_items",
                period:,
                group: group.name,
                order: "topics_entered",
                ascending:,
              )
            if kind == "PM-off"
              expect_blocked(response)
            else
              expected_ids = ascending ? [bravo.id, alpha.id] : [alpha.id, bravo.id]
              expect(content(response).fetch(:directory_items).pluck(:id)).to eq(expected_ids)
            end
          end
        end
      end

      it "handles directory ordering by posts_read #{kind}" do
        group, alpha, bravo = directory_fixture
        activate_rule(kind)

        %w[all daily].each do |period|
          [false, true].each do |ascending|
            response =
              tool(
                "discourse_list_directory_items",
                period:,
                group: group.name,
                order: "posts_read",
                ascending:,
              )
            if kind == "PM-off"
              expect_blocked(response)
            else
              expected_ids = ascending ? [bravo.id, alpha.id] : [alpha.id, bravo.id]
              expect(content(response).fetch(:directory_items).pluck(:id)).to eq(expected_ids)
            end
          end
        end
      end

      it "preserves all other automatic directory orders and username order #{kind}" do
        group, alpha, bravo = directory_fixture
        activate_rule(kind)
        orders = %w[likes_received likes_given topic_count post_count days_visited username]

        orders.each do |order|
          [false, true].each do |ascending|
            result =
              content(
                tool(
                  "discourse_list_directory_items",
                  period: "all",
                  group: group.name,
                  order:,
                  ascending:,
                ),
              )
            expected_ids = ascending ? [alpha.id, bravo.id] : [bravo.id, alpha.id]
            expect(result.fetch(:directory_items).pluck(:id)).to eq(expected_ids)
          end
        end
      end
    end

    include_examples "directory metrics", "PM-off"
    include_examples "directory metrics", "an unrelated rule"
    include_examples "directory metrics", "without rule rows"
  end

  describe "get_user_summary badge post references" do
    fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
    let(:client) do
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Badge reference client",
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
    let(:raw_token) { McpOauthAccessToken.issue!(authorization:) }
    let(:token) { McpOauthAccessToken.find_by!(token_hash: McpOauthAccessToken.digest(raw_token)) }

    before do
      DiscourseMcp.reset_registry!
      SiteSetting.mcp_server_enabled = true
      SiteSetting.enable_badges = false
    end

    around do |example|
      original_registry = DiscourseMcp.registry
      example.run
    ensure
      DiscourseMcp.instance_variable_set(:@registry, original_registry)
    end

    def activate_rule(kind)
      expect(McpContentRule.count).to eq(0)
      McpContentRule.create!(rule_kind: "private_messages", config: {}) if kind == "PM-off"
    end

    def tool(name, arguments = {})
      McpPrimitive.find_or_create_by!(kind: "tool", identifier: name).update!(enabled: true)
      expect(DiscourseMcp.registry.find(:tool, name)).to be_present
      request = ActionDispatch::TestRequest.create
      request.headers["MCP-Protocol-Version"] = DiscourseMcp::LEGACY_PROTOCOL_VERSION
      DiscourseMcp::Server.new(
        request:,
        request_context: DiscourseMcp::RequestContext.new(token),
      ).call(
        {
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => {
            "name" => name,
            "arguments" => arguments.deep_stringify_keys,
          },
        },
      )
    end

    def content(response)
      expect(response.http_status).to eq(200)
      expect(response.body[:error]).to be_nil
      expect(response.body.dig(:result, :isError)).to eq(false)
      structured = response.body.fetch(:result).fetch(:structuredContent).deep_symbolize_keys
      text = response.body.fetch(:result).fetch(:content).sole.fetch(:text)
      serialized = JSON.parse(JSON.generate(structured), symbolize_names: true)
      expect(JSON.parse(text, symbolize_names: true)).to eq(serialized)
      serialized
    end

    shared_examples "summary badge post references" do |kind|
      it "protects PM badge references and preserves public badge references #{kind}" do
        SiteSetting.enable_badges = true
        public_post = Fabricate(:post, user: admin, topic: Fabricate(:topic, user: admin))
        message = Fabricate(:private_message_post, user: admin)
        public_grant =
          Fabricate(
            :user_badge,
            user: admin,
            granted_by: admin,
            badge: Fabricate(:badge, enabled: true, show_posts: true),
            post: public_post,
            is_favorite: true,
          )
        private_grant =
          Fabricate(
            :user_badge,
            user: admin,
            granted_by: admin,
            badge: Fabricate(:badge, enabled: true, show_posts: true),
            post: message,
            is_favorite: true,
          )
        native = content(tool("discourse_get_user_summary", username: admin.username))
        native_badges = native.fetch(:badges)
        expect(native_badges.pluck(:id)).to contain_exactly(public_grant.id, private_grant.id)
        expect(native_badges.find { |badge| badge[:id] == public_grant.id }).to include(
          post_id: public_post.id,
          post_number: public_post.post_number,
          topic_id: public_post.topic_id,
        )
        expect(native_badges.find { |badge| badge[:id] == private_grant.id }).to include(
          post_id: message.id,
          post_number: message.post_number,
          topic_id: message.topic_id,
        )
        activate_rule(kind)

        result = content(tool("discourse_get_user_summary", username: admin.username))

        if kind == "without rule rows"
          expect(result).to eq(native)
        else
          badges = result.fetch(:badges)
          aggregate_failures do
            expect(badges.find { |badge| badge[:id] == public_grant.id }).to eq(
              native_badges.find { |badge| badge[:id] == public_grant.id },
            )
            badges
              .select { |badge| badge[:id] == private_grant.id }
              .each do |badge|
                expect(badge.slice(:post_id, :post_number, :topic_id).compact).to be_empty
              end
          end
        end
      end
    end

    include_examples "summary badge post references", "PM-off"
    include_examples "summary badge post references", "without rule rows"
  end
end
