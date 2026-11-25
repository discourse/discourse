# frozen_string_literal: true

describe DiscourseMcp::Server do
  describe "topicless consolidated notifications" do
    fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
    let(:client) do
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Consolidated notification client",
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
      serialized = JSON.parse(JSON.generate(structured), symbolize_names: true)
      expect(JSON.parse(text, symbolize_names: true)).to eq(serialized)
      serialized
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

    def consolidated_likes(post, liker)
      notification = nil
      2.times do
        notification =
          Notification.consolidate_or_create!(
            notification_type: Notification.types[:liked],
            user_id: admin.id,
            topic_id: post.topic_id,
            post_number: post.post_number,
            data: {
              topic_title: post.topic.title,
              original_post_id: post.id,
              original_username: post.user.username,
              display_username: liker.username,
            }.to_json,
          )
      end
      expect(notification).to have_attributes(
        notification_type: Notification.types[:liked_consolidated],
        topic_id: nil,
      )
      expect(notification.data_hash).to include(
        topic_title: post.topic.title,
        original_post_id: post.id,
        count: 2,
      )
      notification
    end

    shared_examples "topicless consolidated notifications" do |kind|
      it "filters PM-only consolidations before the notification page limit #{kind}" do
        SiteSetting.notification_consolidation_threshold = 1
        admin.user_option.update!(
          like_notification_frequency:
            UserOption.like_notification_frequency_type[:first_time_and_daily],
        )
        public_post =
          Fabricate(
            :post,
            user: admin,
            topic: Fabricate(:topic, user: admin, title: "Public round three likes"),
          )
        message = Fabricate(:private_message_post, user: admin)
        message.topic.update!(title: "Confidential round three likes")
        public_notification = consolidated_likes(public_post, Fabricate(:user))
        private_notification = consolidated_likes(message, Fabricate(:user))
        expect(private_notification.id).to be > public_notification.id
        native = content(tool("discourse_notification_list"))
        expect(native.fetch(:notifications).pluck(:id)).to eq(
          [private_notification.id, public_notification.id],
        )
        activate_rule(kind)

        [50, 1].each do |limit|
          response = tool("discourse_notification_list", limit:)
          result = content(response)

          aggregate_failures("limit #{limit}") do
            if kind == "without rule rows"
              expect(result).to eq(notifications: native.fetch(:notifications).first(limit))
              expect(JSON.generate(response.body)).to include(message.topic.title)
            else
              native_notification = native.fetch(:notifications).last
              representative_data =
                native_notification.fetch(:data).slice(
                  :topic_title,
                  :original_post_id,
                  :original_post_type,
                  :original_username,
                  :revision_number,
                  :display_username,
                  :display_name,
                  :username,
                )
              expect(result).to eq(
                notifications: [native_notification.merge(data: representative_data)],
              )
              expect(JSON.generate(response.body)).not_to include(message.topic.title)
            end
          end
        end
      end
    end

    include_examples "topicless consolidated notifications", "PM-off"
    include_examples "topicless consolidated notifications", "without rule rows"
  end

  describe "mixed consolidated notification aggregates" do
    fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
    let(:client) do
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Notification aggregate client",
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

    def normalized_notifications(result)
      result.merge(
        notifications:
          result
            .fetch(:notifications)
            .map { |notification| notification.except(:id, :created_at, :updated_at) },
      )
    end

    def notification_history(posts, liker, kind)
      snapshot = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        posts.each do |post|
          action = Fabricate(:post_action, user: liker, post:)
          PostAlerter.new.create_notification(
            admin,
            Notification.types[:liked],
            post,
            display_username: liker.username,
            post_action_id: action.id,
            user_id: liker.id,
          )
        end
        notification = Notification.where(user: admin).sole
        expect(notification).to have_attributes(
          notification_type: Notification.types[:liked_consolidated],
          topic_id: nil,
        )
        expect(notification.data_hash).to include(
          count: posts.size,
          original_post_id: posts.last.id,
          topic_title: posts.last.topic.title,
          display_username: liker.username,
        )
        native = content(tool("discourse_notification_list"))
        expect(native.fetch(:notifications)).to contain_exactly(
          a_hash_including(
            id: notification.id,
            notification_type: Notification.types[:liked_consolidated],
            data: a_hash_including(count: posts.size, original_post_id: posts.last.id),
          ),
        )
        activate_rule(kind)
        result = content(tool("discourse_notification_list"))

        # Only JSON snapshots leave the savepoint; none of its records survive rollback.
        snapshot = { native:, result: }
        raise ActiveRecord::Rollback
      end
      snapshot
    end

    shared_examples "mixed consolidated notification aggregates" do |kind|
      it "applies the aggregate contract to public-only and mixed like histories #{kind}" do
        freeze_time
        SiteSetting.notification_consolidation_threshold = 1
        admin.user_option.update!(
          like_notification_frequency:
            UserOption.like_notification_frequency_type[:first_time_and_daily],
        )
        liker = Fabricate(:user, trust_level: TrustLevel[2], refresh_auto_groups: true)
        public_posts =
          2.times.map { Fabricate(:post, user: admin, topic: Fabricate(:topic, user: admin)) }
        message = Fabricate(:private_message_post, user: admin, recipient: liker)

        # Materialize the memoized OAuth records and tool before either history rolls back.
        expect(content(tool("discourse_notification_list"))).to eq(notifications: [])
        public_only = notification_history(public_posts, liker, kind)
        mixed = notification_history([message, *public_posts], liker, kind)

        aggregate_failures do
          if kind == "without rule rows"
            expect(public_only.fetch(:result)).to eq(public_only.fetch(:native))
            expect(public_only.fetch(:result).fetch(:notifications)).to contain_exactly(
              a_hash_including(data: a_hash_including(count: public_posts.size)),
            )
            expect(mixed.fetch(:result)).to eq(mixed.fetch(:native))
            expect(mixed.fetch(:result).fetch(:notifications)).to contain_exactly(
              a_hash_including(data: a_hash_including(count: public_posts.size + 1)),
            )
            expect(normalized_notifications(mixed.fetch(:result))).not_to eq(
              normalized_notifications(public_only.fetch(:result)),
            )
          else
            # The representative public post cannot prove any aggregate is PM-free.
            [public_only, mixed].each do |history|
              native_notification = history.fetch(:native).fetch(:notifications).sole
              representative_data =
                native_notification.fetch(:data).slice(
                  :topic_title,
                  :original_post_id,
                  :original_post_type,
                  :original_username,
                  :revision_number,
                  :display_username,
                  :display_name,
                  :username,
                )
              expect(history.fetch(:result).fetch(:notifications)).to eq(
                [native_notification.merge(data: representative_data)],
              )
            end
            expect(normalized_notifications(mixed.fetch(:result))).to eq(
              normalized_notifications(public_only.fetch(:result)),
            )
          end
        end
      end
    end

    include_examples "mixed consolidated notification aggregates", "PM-off"
    include_examples "mixed consolidated notification aggregates", "without rule rows"
  end
end
