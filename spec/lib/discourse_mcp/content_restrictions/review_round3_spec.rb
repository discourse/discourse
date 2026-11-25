# frozen_string_literal: true

require "base64"

describe DiscourseMcp::Server, "#call [cr-u1] round 3 regressions" do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  let(:image_bytes) { File.binread(file_from_fixtures("logo.png").path) }
  let(:client) do
    McpOauthClient.create!(
      client_id: SecureRandom.hex,
      name: "Round 3 regression oracle",
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

  shared_examples "[cr-u1] topicless consolidated notifications" do |kind|
    it "[cr-u1] filters PM-only consolidations before the notification page limit #{kind}" do
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

  include_examples "[cr-u1] topicless consolidated notifications", "PM-off"
  include_examples "[cr-u1] topicless consolidated notifications", "without rule rows"

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

  shared_examples "[cr-u1] reviewable explanations" do |kind|
    it "[cr-u1] removes per-user flag counters throughout get_reviewable with explanations #{kind}" do
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

    it "[cr-u1] keeps get_reviewable with explanations stable after the same flagger resolves PM flags #{kind}" do
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
              before_resolution.fetch(:explanation).map { |score| score.merge(expected_counters) },
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

  include_examples "[cr-u1] reviewable explanations", "PM-off"
  include_examples "[cr-u1] reviewable explanations", "an unrelated rule"
  include_examples "[cr-u1] reviewable explanations", "without rule rows"

  def upload_arguments
    {
      upload_type: "composer",
      image_data: Base64.strict_encode64(image_bytes),
      filename: "caller-image.png",
    }
  end

  shared_examples "[cr-u1] same-user concurrent upload" do |kind|
    it "[cr-u1] rejects a newer same-user upload returned by the real deduplication path #{kind}" do
      freeze_time
      call_started_at = Time.zone.now
      raced_upload = nil
      raced_upload_id = nil
      deduplicated_upload = nil
      expect(Upload.where(sha1: Digest::SHA1.hexdigest(image_bytes))).not_to exist
      activate_rule(kind)
      original_user_upload_ids = UserUpload.order(:id).pluck(:id)

      allow(UploadsController).to receive(
        :create_upload,
      ).and_wrap_original do |create_upload, **options|
        freeze_time(call_started_at + 1.second)
        # Pause a competing request after its Upload insert, before its ownership grant.
        raced_upload =
          Fabricate.build(
            :upload,
            user: admin,
            sha1: Digest::SHA1.hexdigest(image_bytes),
            original_filename: "concurrent-request-image.png",
          )
        raced_upload.save!
        # Refusal rolls back this simulated insert and clears the model's ID.
        raced_upload_id = raced_upload.id
        expect(UserUpload.where(user: admin, upload: raced_upload)).not_to exist

        deduplicated_upload = create_upload.call(**options)
      end

      response = tool("discourse_upload_file", upload_arguments)

      expect(raced_upload.created_at).to be > call_started_at
      expect(raced_upload.user_id).to eq(admin.id)
      expect(deduplicated_upload).to be_a(Upload)
      expect(deduplicated_upload.id).to eq(raced_upload_id)
      expect(deduplicated_upload).not_to equal(raced_upload)
      expect(deduplicated_upload.previously_new_record?).to eq(false)
      if kind == "without rule rows"
        expect(content(response)).to include(
          id: raced_upload.id,
          url: UrlHelper.cook_url(raced_upload.url),
          short_url: raced_upload.short_url,
          original_filename: raced_upload.original_filename,
        )
        expect(UserUpload.where(user: admin, upload: raced_upload)).to exist
        expect(UserUpload.count).to eq(original_user_upload_ids.size + 1)
      else
        aggregate_failures do
          expect_blocked(response)
          expect(JSON.generate(response.body)).not_to include(
            UrlHelper.cook_url(raced_upload.url),
            raced_upload.short_url,
            raced_upload.original_filename,
          )
          expect(UserUpload.order(:id).pluck(:id)).to eq(original_user_upload_ids)
          expect(UserUpload.where(user: admin, upload_id: deduplicated_upload.id)).not_to exist
        end
      end
    end

    it "[cr-u1] permits uploads actually created by this call #{kind}" do
      expect(Upload.where(sha1: Digest::SHA1.hexdigest(image_bytes))).not_to exist
      activate_rule(kind)
      response = nil

      expect { response = tool("discourse_upload_file", upload_arguments) }.to change {
        Upload.count
      }.by(1).and change { UserUpload.where(user: admin).count }.by(1)

      result = content(response)
      upload = Upload.find(result.fetch(:id))
      expect(upload).to have_attributes(user_id: admin.id, original_filename: "caller-image.png")
      expect(result.fetch(:url)).to eq(UrlHelper.cook_url(upload.url))
      expect(UserUpload.where(user: admin, upload:)).to exist
    end
  end

  include_examples "[cr-u1] same-user concurrent upload", "PM-off"
  include_examples "[cr-u1] same-user concurrent upload", "an unrelated rule"
  include_examples "[cr-u1] same-user concurrent upload", "without rule rows"
end
