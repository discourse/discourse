# frozen_string_literal: true

require "base64"

describe DiscourseMcp::Server, "#call [cr-u1] round 2 regressions" do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  let(:image_bytes) { File.binread(file_from_fixtures("logo.png").path) }
  let(:client) do
    McpOauthClient.create!(
      client_id: SecureRandom.hex,
      name: "Round 2 regression oracle",
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

  def upload_arguments
    {
      upload_type: "composer",
      image_data: Base64.strict_encode64(image_bytes),
      filename: "caller-image.png",
    }
  end

  shared_examples "[cr-u1] upload race" do |kind|
    it "[cr-u1] handles another user's upload created during upload_file #{kind}" do
      freeze_time
      owner = Fabricate(:user)
      call_started_at = Time.zone.now
      raced_upload = nil
      activate_rule(kind)

      # Model the deduplication winner and its ownership grant inside the creation path.
      allow(UploadsController).to receive(:create_upload) do |**options|
        freeze_time(call_started_at + 1.second)
        raced_upload =
          Fabricate(
            :upload,
            user: owner,
            sha1: Digest::SHA1.hexdigest(image_bytes),
            original_filename: "other-users-image.png",
          )
        UserUpload.create!(user: options.fetch(:current_user), upload: raced_upload)
        raced_upload
      end

      response = tool("discourse_upload_file", upload_arguments)

      expect(raced_upload.created_at).to be > call_started_at
      expect(raced_upload.user_id).to eq(owner.id)
      if kind == "without rule rows"
        expect(content(response)).to include(
          id: raced_upload.id,
          url: UrlHelper.cook_url(raced_upload.url),
          short_url: raced_upload.short_url,
          original_filename: raced_upload.original_filename,
        )
        expect(UserUpload.where(user: admin, upload: raced_upload)).to exist
      else
        aggregate_failures do
          expect_blocked(response)
          expect(JSON.generate(response.body)).not_to include(
            UrlHelper.cook_url(raced_upload.url),
            raced_upload.short_url,
            raced_upload.original_filename,
          )
          expect(UserUpload.where(user: admin, upload: raced_upload)).not_to exist
        end
      end
    end

    it "[cr-u1] permits the caller's own fresh upload_file #{kind}" do
      expect(Upload.where(sha1: Digest::SHA1.hexdigest(image_bytes))).not_to exist
      activate_rule(kind)
      response = nil

      expect { response = tool("discourse_upload_file", upload_arguments) }.to change {
        Upload.count
      }.by(1)

      result = content(response)
      upload = Upload.find(result.fetch(:id))
      expect(upload).to have_attributes(user_id: admin.id, original_filename: "caller-image.png")
      expect(UserUpload.where(user: admin, upload:)).to exist
    end
  end

  include_examples "[cr-u1] upload race", "PM-off"
  include_examples "[cr-u1] upload race", "an unrelated rule"
  include_examples "[cr-u1] upload race", "without rule rows"

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

  shared_examples "[cr-u1] reviewable user counters" do |kind|
    it "[cr-u1] filters score and flagged-user counters in list_reviewables and get_reviewable #{kind}" do
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

    it "[cr-u1] keeps public reviewable responses stable across PM flag resolutions #{kind}" do
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
        expect([author, reporter].map { |user| user.user_stat.reload.public_send(counter) }).to eq(
          [1, 1],
        )

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

    it "[cr-u1] keeps list_reviewable_topics and its claimant free of user counters #{kind}" do
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

  include_examples "[cr-u1] reviewable user counters", "PM-off"
  include_examples "[cr-u1] reviewable user counters", "an unrelated rule"
  include_examples "[cr-u1] reviewable user counters", "without rule rows"

  shared_examples "[cr-u1] summary metrics" do |kind|
    it "[cr-u1] filters all eight unsafe get_user_summary metrics and preserves bookmarks #{kind}" do
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
        expect(result.fetch(:top_replies).pluck(:post_number)).to include(public_reply.post_number)
      else
        expect(result).to eq(native)
      end
    end

    it "[cr-u1] makes a PM-only reader indistinguishable from an inactive summary user #{kind}" do
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

  include_examples "[cr-u1] summary metrics", "PM-off"
  include_examples "[cr-u1] summary metrics", "an unrelated rule"
  include_examples "[cr-u1] summary metrics", "without rule rows"

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

  shared_examples "[cr-u1] directory metrics" do |kind|
    it "[cr-u1] filters directory reading values while preserving other columns #{kind}" do
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

    it "[cr-u1] handles directory ordering by topics_entered #{kind}" do
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

    it "[cr-u1] handles directory ordering by posts_read #{kind}" do
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

    it "[cr-u1] preserves all other automatic directory orders and username order #{kind}" do
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

  include_examples "[cr-u1] directory metrics", "PM-off"
  include_examples "[cr-u1] directory metrics", "an unrelated rule"
  include_examples "[cr-u1] directory metrics", "without rule rows"
end
