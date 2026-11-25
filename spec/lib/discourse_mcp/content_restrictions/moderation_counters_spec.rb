# frozen_string_literal: true

describe DiscourseMcp::Server do
  describe "moderation and queue counters" do
    fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
    let(:client) do
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Moderation counter client",
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

    def seed_private_moderation_activity(user)
      deleted = Fabricate(:private_message_post, user:, recipient: admin)
      deleted.trash!
      flagged = Fabricate(:private_message_post, user:, recipient: admin)
      Fabricate(
        :reviewable_flagged_post,
        topic: flagged.topic,
        target: flagged,
        target_created_by: user,
      )
      received = Fabricate(:private_message_post, user: admin, recipient: user)
      received.topic.update!(subtype: TopicSubtype.moderator_warning)
      Fabricate(
        :post_action,
        user:,
        post: received,
        post_action_type_id: PostActionType.types[:spam],
      )
      UserWarning.create!(user:, topic: received.topic, created_by: admin)
      Fabricate(
        :reviewable_queued_post,
        topic: flagged.topic,
        target_created_by: user,
        status: Reviewable.statuses[:rejected],
      )
    end

    shared_examples "restricted moderation counters" do |kind|
      it "hides all content-derived moderation counters and makes PM-only activity indistinguishable with #{kind} active" do
        active_user = Fabricate(:user)
        inactive_user = Fabricate(:user)
        seed_private_moderation_activity(active_user)
        counters = %i[deleted_posts flags_received flags_given rejected_posts warnings_received]
        unrestricted =
          content(tool("discourse_get_user_moderation_summary", username: active_user.username))
        expect(unrestricted.slice(*counters)).to eq(
          deleted_posts: 1,
          flags_received: 2,
          flags_given: 1,
          rejected_posts: 1,
          warnings_received: 1,
        )
        activate_rule(kind)

        active =
          content(tool("discourse_get_user_moderation_summary", username: active_user.username))
        inactive =
          content(tool("discourse_get_user_moderation_summary", username: inactive_user.username))

        aggregate_failures do
          expect(active.keys).not_to include(*counters)
          expect(inactive.keys).not_to include(*counters)
          expect(active.except(:username)).to eq(inactive.except(:username))
        end
      end
    end

    include_examples "restricted moderation counters", "PM-off"
    include_examples "restricted moderation counters", "an unrelated rule"

    it "preserves all native moderation counters without rule rows" do
      user = Fabricate(:user)
      seed_private_moderation_activity(user)
      %i[silence_user suspend_user].each do |action|
        Fabricate(
          :user_history,
          acting_user: admin,
          target_user_id: user.id,
          action: UserHistory.actions[action],
        )
      end

      result = content(tool("discourse_get_user_moderation_summary", username: user.username))

      expect(result).to eq(
        username: user.username,
        deleted_posts: 1,
        flags_received: 2,
        flags_given: 1,
        rejected_posts: 1,
        warnings_received: 1,
        silencings: 1,
        suspensions: 1,
      )
    end

    shared_examples "restricted queue counters" do |kind|
      it "performs an ordinary reviewable action without queue counts with #{kind} active" do
        message = Fabricate(:private_message_post, user: admin)
        hidden = Fabricate(:reviewable_flagged_post, topic: message.topic, target: message)
        reviewable = Fabricate(:reviewable_queued_post)
        expect(Reviewable.list_for(admin, preload: false).pluck(:id)).to include(
          hidden.id,
          reviewable.id,
        )
        activate_rule(kind)
        if kind == "PM-off"
          expect(content(tool("discourse_get_review_queue_count")).fetch(:count)).to eq(1)
        end

        result =
          content(
            tool(
              "discourse_perform_reviewable_action",
              reviewable_id: reviewable.id,
              action_id: "reject_post",
              expected_version: reviewable.version,
              confirm: true,
            ),
          )

        expect(result).to include(success: true, reviewable_id: reviewable.id)
        expect(reviewable.reload).to be_rejected
        expect(hidden.reload).to be_pending
        expect(result.keys).not_to include(:reviewable_count, :unseen_reviewable_count)
      end
    end

    include_examples "restricted queue counters", "PM-off"
    include_examples "restricted queue counters", "an unrelated rule"

    it "preserves reviewable action queue counts including PM reviewables without rule rows" do
      message = Fabricate(:private_message_post, user: admin)
      hidden = Fabricate(:reviewable_flagged_post, topic: message.topic, target: message)
      reviewable = Fabricate(:reviewable_queued_post)
      admin.update!(last_seen_reviewable_id: 0)

      result =
        content(
          tool(
            "discourse_perform_reviewable_action",
            reviewable_id: reviewable.id,
            action_id: "reject_post",
            expected_version: reviewable.version,
            confirm: true,
          ),
        )

      expect(reviewable.reload).to be_rejected
      expect(hidden.reload).to be_pending
      expect(result).to include(success: true, reviewable_count: 1, unseen_reviewable_count: 1)
    end
  end

  describe "reviewable user counters" do
    fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
    let(:client) do
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Reviewable counter client",
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

    def reviewable_fixture
      author = Fabricate(:user, trust_level: TrustLevel[2], refresh_auto_groups: true)
      reporter = Fabricate(:user, trust_level: TrustLevel[2], refresh_auto_groups: true)
      post = Fabricate(:post, user: author)
      reviewable =
        Fabricate(
          :reviewable_flagged_post,
          topic: post.topic,
          category: post.topic.category,
          target: post,
          target_created_by: author,
          score: 999,
          reviewable_scores: [
            Fabricate.build(:reviewable_score, user: reporter, status: :pending, reviewed_by: nil),
          ],
        )
      [reviewable, author, reporter]
    end

    def public_reviewable_responses(reviewable)
      results = {
        list: content(tool("discourse_list_reviewables", topic_id: reviewable.topic_id)),
        detail: content(tool("discourse_get_reviewable", reviewable_id: reviewable.id)),
      }
      expect(results.fetch(:list).fetch(:reviewables).pluck(:id)).to eq([reviewable.id])
      expect(results.fetch(:detail).fetch(:reviewable).fetch(:id)).to eq(reviewable.id)
      results
    end

    def counter_values(value, fields)
      case value
      when Hash
        value.slice(*fields).values.compact +
          value.values.flat_map { |item| counter_values(item, fields) }
      when Array
        value.flat_map { |item| counter_values(item, fields) }
      else
        []
      end
    end

    shared_examples "reviewable user counters" do |kind|
      it "filters score and flagged-user counters in list_reviewables and get_reviewable #{kind}" do
        reviewable, author, reporter = reviewable_fixture
        author.user_stat.update!(
          flags_agreed: 4,
          flags_disagreed: 2,
          flags_ignored: 1,
          post_count: 7,
          topic_count: 5,
        )
        reporter.user_stat.update!(flags_agreed: 8, flags_disagreed: 6, flags_ignored: 2)
        message = Fabricate(:private_message_post, recipient: author)
        Fabricate(
          :reviewable_queued_post,
          topic: message.topic,
          target_created_by: author,
          status: :rejected,
        )
        counters = %i[
          agree_stats
          flags_agreed
          flags_disagreed
          flags_ignored
          post_count
          topic_count
          rejected_posts_count
        ]
        native = public_reviewable_responses(reviewable)
        native.each_value do |result|
          expect(result.fetch(:users)).to include(
            a_hash_including(
              id: author.id,
              flags_agreed: 4,
              flags_disagreed: 2,
              flags_ignored: 1,
              post_count: 7,
              topic_count: 5,
              rejected_posts_count: 1,
              silenced_count: 0,
              suspended_count: 0,
            ),
          )
          expect(result.fetch(:reviewable_scores)).to include(
            a_hash_including(
              id: reviewable.reviewable_scores.sole.id,
              agree_stats: {
                agreed: 8,
                disagreed: 6,
                ignored: 2,
              },
            ),
          )
        end
        activate_rule(kind)

        public_reviewable_responses(reviewable).each do |endpoint, result|
          aggregate_failures(endpoint) do
            if kind == "without rule rows"
              expect(result).to eq(native.fetch(endpoint))
            else
              expect(counter_values(result, counters)).to be_empty
              expect(result.fetch(:users)).to include(a_hash_including(id: author.id))
              expect(result.fetch(:reviewable_scores)).to include(
                a_hash_including(id: reviewable.reviewable_scores.sole.id),
              )
            end
          end
        end
      end

      it "keeps public reviewable responses stable across PM flag resolutions #{kind}" do
        freeze_time
        reviewable, author, reporter = reviewable_fixture
        activate_rule(kind)
        before_resolution = public_reviewable_responses(reviewable)
        expect(before_resolution.fetch(:list).fetch(:reviewables).pluck(:id)).to eq([reviewable.id])
        expect(before_resolution.fetch(:detail).fetch(:reviewable).fetch(:id)).to eq(reviewable.id)

        {
          agree_and_keep: :flags_agreed,
          disagree: :flags_disagreed,
          ignore_and_do_nothing: :flags_ignored,
        }.each do |action, counter|
          message = Fabricate(:private_message_post, recipient: reporter)
          message.topic.allowed_users << author
          hidden = PostActionCreator.off_topic(reporter, message).reviewable
          expect(hidden).to be_persisted
          expect(PostActionCreator.off_topic(author, message).reviewable.id).to eq(hidden.id)
          expect(hidden.reload.perform(admin, action)).to be_success
          expect(
            [author, reporter].map { |user| user.user_stat.reload.public_send(counter) },
          ).to eq([1, 1])

          public_reviewable_responses(reviewable).each do |endpoint, result|
            aggregate_failures("#{endpoint}: #{action}") do
              if kind == "without rule rows"
                expect(result.fetch(:users)).to include(
                  a_hash_including(:id => author.id, counter => 1),
                )
                expect(result.fetch(:reviewable_scores).sole.fetch(:agree_stats)).to include(
                  counter.to_s.delete_prefix("flags_").to_sym => 1,
                )
                expect(result).not_to eq(before_resolution.fetch(endpoint))
              else
                expect(result).to eq(before_resolution.fetch(endpoint))
              end
            end
          end
        end
      end

      it "keeps list_reviewable_topics and its claimant free of user counters #{kind}" do
        reviewable, author, = reviewable_fixture
        author.user_stat.update!(flags_agreed: 4, post_count: 7, topic_count: 5)
        ReviewableClaimedTopic.create!(topic: reviewable.topic, user: author, automatic: true)
        native = content(tool("discourse_list_reviewable_topics"))
        expect(native.fetch(:topics).pluck(:id)).to eq([reviewable.topic_id])
        activate_rule(kind)

        result = content(tool("discourse_list_reviewable_topics"))

        expect(result.fetch(:topics).pluck(:id)).to eq([reviewable.topic_id])
        expect(
          counter_values(
            result,
            %i[
              agree_stats
              flags_agreed
              flags_disagreed
              flags_ignored
              post_count
              topic_count
              rejected_posts_count
            ],
          ),
        ).to be_empty
        expect(result).to eq(native) if kind == "without rule rows"
      end
    end

    include_examples "reviewable user counters", "PM-off"
    include_examples "reviewable user counters", "an unrelated rule"
    include_examples "reviewable user counters", "without rule rows"
  end

  describe "reviewable explanations" do
    fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
    let(:client) do
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Reviewable explanation client",
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

    def reviewable_fixture
      author = Fabricate(:user, trust_level: TrustLevel[2], refresh_auto_groups: true)
      reporter = Fabricate(:user, trust_level: TrustLevel[2], refresh_auto_groups: true)
      post = Fabricate(:post, user: author, topic: Fabricate(:topic, user: author))
      reviewable =
        Fabricate(
          :reviewable_flagged_post,
          topic: post.topic,
          category: post.topic.category,
          target: post,
          target_created_by: author,
          score: 999,
          reviewable_scores: [
            Fabricate.build(:reviewable_score, user: reporter, status: :pending, reviewed_by: nil),
          ],
        )
      [reviewable, reporter]
    end

    def reviewable_with_explanation(reviewable)
      result =
        content(
          tool("discourse_get_reviewable", reviewable_id: reviewable.id, include_explanation: true),
        )
      expect(result.fetch(:reviewable).fetch(:id)).to eq(reviewable.id)
      result
    end

    def flag_counter_keys(value)
      case value
      when Hash
        (value.keys & %i[flags_agreed flags_disagreed flags_ignored]) +
          value.values.flat_map { |item| flag_counter_keys(item) }
      when Array
        value.flat_map { |item| flag_counter_keys(item) }
      else
        []
      end
    end

    shared_examples "reviewable explanations" do |kind|
      it "removes per-user flag counters throughout get_reviewable with explanations #{kind}" do
        reviewable, reporter = reviewable_fixture
        reporter.user_stat.update!(flags_agreed: 4, flags_disagreed: 2, flags_ignored: 1)
        native = reviewable_with_explanation(reviewable)
        expect(native.fetch(:explanation)).to contain_exactly(
          a_hash_including(
            reviewable_id: reviewable.id,
            user_id: reporter.id,
            flags_agreed: 4,
            flags_disagreed: 2,
            flags_ignored: 1,
            score: reviewable.reviewable_scores.sole.score,
            trust_level_bonus: 2,
          ),
        )
        activate_rule(kind)

        result = reviewable_with_explanation(reviewable)

        if kind == "without rule rows"
          expect(result).to eq(native)
        else
          expect(flag_counter_keys(result)).to be_empty
        end
      end

      it "keeps get_reviewable with explanations stable after the same flagger resolves PM flags #{kind}" do
        freeze_time
        reviewable, reporter = reviewable_fixture
        activate_rule(kind)
        before_resolution = reviewable_with_explanation(reviewable)

        {
          agree_and_keep: :flags_agreed,
          disagree: :flags_disagreed,
          ignore_and_do_nothing: :flags_ignored,
        }.each do |action, counter|
          message = Fabricate(:private_message_post, recipient: reporter)
          hidden = PostActionCreator.off_topic(reporter, message).reviewable
          expect(hidden).to be_persisted
          expect(hidden.reviewable_scores.pluck(:user_id)).to eq([reporter.id])
          expect(hidden.perform(admin, action)).to be_success
          expect(reporter.user_stat.reload.public_send(counter)).to eq(1)

          result = reviewable_with_explanation(reviewable)

          aggregate_failures(action) do
            if kind == "without rule rows"
              expected_counters =
                reporter.user_stat.attributes.symbolize_keys.slice(
                  :flags_agreed,
                  :flags_disagreed,
                  :flags_ignored,
                )
              expect(result.fetch(:explanation)).to eq(
                before_resolution
                  .fetch(:explanation)
                  .map { |score| score.merge(expected_counters) },
              )
              expect(result).not_to eq(before_resolution)
            else
              expect(result).to eq(before_resolution)
              expect(flag_counter_keys(result)).to be_empty
            end
          end
        end
      end
    end

    include_examples "reviewable explanations", "PM-off"
    include_examples "reviewable explanations", "an unrelated rule"
    include_examples "reviewable explanations", "without rule rows"
  end
end
