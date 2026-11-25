# frozen_string_literal: true

require "base64"

describe DiscourseMcp::Server do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  let(:image_bytes) { File.binread(file_from_fixtures("logo.png").path) }
  let(:client) do
    McpOauthClient.create!(
      client_id: SecureRandom.hex,
      name: "Review fixes oracle",
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

  def pm_upload(owner)
    Group.refresh_automatic_groups_for_user!(owner)
    upload =
      UploadCreator.new(
        file_from_fixtures("logo.png"),
        "pm-attachment.png",
        type: "composer",
        for_private_message: true,
      ).create_for(owner.id)
    expect(upload).to be_persisted
    post =
      Fabricate(
        :private_message_post,
        user: owner,
        raw: "![#{upload.original_filename}](#{upload.short_url})",
      )
    post.link_post_uploads
    expect(UploadReference.where(target: post, upload:)).to exist
    upload
  end

  def signup_arguments
    suffix = SecureRandom.hex(6)
    {
      username: "mcp_#{suffix}",
      email: "mcp_#{suffix}@example.com",
      name: "MCP regression user",
      password: "Strong-password-#{suffix}!",
    }
  end

  def seed_profile_uploads
    upload = Fabricate(:upload, user: admin)
    admin.pick_avatar!(upload.id, type: :custom)
    admin.user_profile.update!(
      profile_background_upload_id: upload.id,
      card_background_upload_id: upload.id,
    )
  end

  def profile_state
    admin.reload
    {
      name: admin.name,
      uploaded_avatar_id: admin.uploaded_avatar_id,
      custom_upload_id: admin.user_avatar.reload.custom_upload_id,
      profile_background_upload_id: admin.user_profile.reload.profile_background_upload_id,
      card_background_upload_id: admin.user_profile.card_background_upload_id,
    }
  end

  shared_examples "restricted existing upload references" do |kind|
    it "[cr-u1] refuses create_user upload_id with #{kind} active and creates no user" do
      uploads = [pm_upload(admin), Fabricate(:upload, user: admin)]
      activate_rule(kind)

      uploads.each do |upload|
        aggregate_failures("upload #{upload.id}") do
          response = nil
          arguments = signup_arguments.merge(upload_id: upload.id)
          expect { response = tool("discourse_create_user", arguments) }.not_to change {
            User.count
          }
          expect_blocked(response)
          expect(User.exists?(username: arguments.fetch(:username))).to eq(false)
        end
      end
    end
  end

  shared_examples "restricted profile upload references" do |kind, field|
    it "[cr-u1] refuses update_user #{field} with #{kind} active and preserves the profile" do
      seed_profile_uploads
      original = profile_state
      uploads = [pm_upload(admin), Fabricate(:upload, user: admin)]
      activate_rule(kind)

      uploads.each do |upload|
        aggregate_failures("upload #{upload.id}") do
          value = field == :upload_id ? upload.id : upload.url
          response =
            tool(
              "discourse_update_user",
              :username => admin.username,
              :name => "Attempted profile change",
              field => value,
            )

          expect_blocked(response)
          expect(profile_state).to eq(original)
        end
      end
    end
  end

  include_examples "restricted existing upload references", "PM-off"
  include_examples "restricted existing upload references", "an unrelated rule"
  include_examples "restricted profile upload references", "PM-off", :upload_id
  include_examples "restricted profile upload references", "PM-off", :profile_background_upload_url
  include_examples "restricted profile upload references", "PM-off", :card_background_upload_url
  include_examples "restricted profile upload references", "an unrelated rule", :upload_id
  include_examples "restricted profile upload references",
                   "an unrelated rule",
                   :profile_background_upload_url
  include_examples "restricted profile upload references",
                   "an unrelated rule",
                   :card_background_upload_url

  it "[cr-u1] permits create_user with a PM attachment upload_id without rule rows" do
    upload = pm_upload(admin)
    response = nil

    expect do
      response = tool("discourse_create_user", signup_arguments.merge(upload_id: upload.id))
    end.to change { User.count }.by(1)

    result = content(response)
    expect(result).to include(created: true, avatar_updated: true)
    user = User.find(result.fetch(:user_id))
    expect(user.uploaded_avatar_id).to eq(upload.id)
    expect(user.user_avatar.custom_upload_id).to eq(upload.id)
  end

  shared_examples "unrestricted profile upload references" do |field|
    it "[cr-u1] permits update_user #{field} using a PM attachment without rule rows" do
      seed_profile_uploads
      upload = pm_upload(admin)
      value = field == :upload_id ? upload.id : upload.url

      result =
        content(tool("discourse_update_user", { :username => admin.username, field => value }))

      expect(result).to include(success: true, updated_fields: [field.to_s])
      if field == :upload_id
        expect(profile_state).to include(uploaded_avatar_id: upload.id, custom_upload_id: upload.id)
      else
        expect(profile_state.fetch(field.to_s.sub("_url", "_id").to_sym)).to eq(upload.id)
      end
    end
  end

  include_examples "unrestricted profile upload references", :upload_id
  include_examples "unrestricted profile upload references", :profile_background_upload_url
  include_examples "unrestricted profile upload references", :card_background_upload_url

  def upload_urls(upload)
    same_site = "#{Discourse.base_url}#{upload.url}"
    redirect = "https://example.com/redirected-attachment.png"
    fresh = "https://example.com/fresh-image.jpg"
    stub_request(:get, same_site).to_return(status: 200, body: image_bytes)
    stub_request(:get, redirect).to_return(status: 302, headers: { "Location" => same_site })
    stub_request(:get, fresh).to_return(
      status: 200,
      body: File.binread(file_from_fixtures("logo.jpg").path),
    )
    [same_site, redirect, fresh]
  end

  shared_examples "restricted file uploads" do |kind|
    it "[cr-u1] refuses upload_file URLs including same-site URLs and redirects with #{kind} active" do
      upload = pm_upload(Fabricate(:user))
      urls = upload_urls(upload)
      activate_rule(kind)

      urls.each do |url|
        aggregate_failures(url) do
          response = nil
          expect do
            response = tool("discourse_upload_file", upload_type: "composer", url:)
          end.not_to change { [Upload.count, UserUpload.where(user: admin).count] }

          expect_blocked(response)
          expect(WebMock).not_to have_requested(:get, url)
        end
      end
    end

    it "[cr-u1] refuses duplicate upload_file bytes without metadata or an ownership grant with #{kind} active" do
      upload = pm_upload(Fabricate(:user))
      expect(UserUpload.where(user: admin, upload:)).not_to exist
      activate_rule(kind)
      response = nil

      aggregate_failures do
        expect do
          response =
            tool(
              "discourse_upload_file",
              upload_type: "composer",
              image_data: Base64.strict_encode64(image_bytes),
              filename: "renamed-attachment.png",
            )
        end.not_to change { [Upload.count, UserUpload.where(user: admin, upload:).count] }

        expect_blocked(response)
        expect(response.body.fetch(:result).keys).not_to include(
          :id,
          :url,
          :short_url,
          :original_filename,
        )
        expect(JSON.generate(response.body)).not_to include(
          upload.url,
          upload.short_url,
          upload.original_filename,
        )
        expect(UserUpload.where(user: admin, upload:)).not_to exist
      end
    end

    it "[cr-u1] permits fresh upload_file bytes with #{kind} active" do
      expect(Upload.where(sha1: Digest::SHA1.hexdigest(image_bytes))).not_to exist
      activate_rule(kind)
      response = nil

      expect do
        response =
          tool(
            "discourse_upload_file",
            upload_type: "composer",
            image_data: Base64.strict_encode64(image_bytes),
            filename: "fresh-image.png",
          )
      end.to change { Upload.count }.by(1)

      result = content(response)
      upload = Upload.find(result.fetch(:id))
      expect(upload).to have_attributes(user_id: admin.id, original_filename: "fresh-image.png")
      expect(UserUpload.where(user: admin, upload:)).to exist
    end
  end

  include_examples "restricted file uploads", "PM-off"
  include_examples "restricted file uploads", "an unrelated rule"

  it "[cr-u1] permits upload_file URLs including same-site URLs and redirects without rule rows" do
    upload = pm_upload(Fabricate(:user))

    upload_urls(upload).each do |url|
      aggregate_failures(url) do
        result = content(tool("discourse_upload_file", upload_type: "composer", url:))

        if url.end_with?("fresh-image.jpg")
          expect(result.fetch(:id)).not_to eq(upload.id)
          expect(result.fetch(:original_filename)).to eq("fresh-image.jpg")
          expect(UserUpload.where(user: admin, upload_id: result.fetch(:id))).to exist
        else
          expect(result).to include(
            id: upload.id,
            url: UrlHelper.cook_url(upload.url),
            short_url: upload.short_url,
            original_filename: upload.original_filename,
          )
        end
        expect(WebMock).to have_requested(:get, url)
      end
    end
    expect(UserUpload.where(user: admin, upload:)).to exist
  end

  it "[cr-u1] returns duplicate upload_file metadata and grants ownership without rule rows" do
    upload = pm_upload(Fabricate(:user))
    expect(UserUpload.where(user: admin, upload:)).not_to exist
    response = nil

    expect do
      response =
        tool(
          "discourse_upload_file",
          upload_type: "composer",
          image_data: Base64.strict_encode64(image_bytes),
          filename: "renamed-attachment.png",
        )
    end.to change { UserUpload.where(user: admin, upload:).count }.by(1)

    expect(content(response)).to include(
      id: upload.id,
      url: UrlHelper.cook_url(upload.url),
      short_url: upload.short_url,
      original_filename: upload.original_filename,
    )
  end

  it "[cr-u1] permits fresh upload_file bytes without rule rows" do
    expect(Upload.where(sha1: Digest::SHA1.hexdigest(image_bytes))).not_to exist
    response = nil

    expect do
      response =
        tool(
          "discourse_upload_file",
          upload_type: "composer",
          image_data: Base64.strict_encode64(image_bytes),
          filename: "fresh-image.png",
        )
    end.to change { Upload.count }.by(1)

    upload = Upload.find(content(response).fetch(:id))
    expect(upload.user_id).to eq(admin.id)
    expect(UserUpload.where(user: admin, upload:)).to exist
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
    Fabricate(:post_action, user:, post: received, post_action_type_id: PostActionType.types[:spam])
    UserWarning.create!(user:, topic: received.topic, created_by: admin)
    Fabricate(
      :reviewable_queued_post,
      topic: flagged.topic,
      target_created_by: user,
      status: Reviewable.statuses[:rejected],
    )
  end

  shared_examples "restricted moderation counters" do |kind|
    it "[cr-u1] hides all content-derived moderation counters and makes PM-only activity indistinguishable with #{kind} active" do
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

  it "[cr-u1] preserves all native moderation counters without rule rows" do
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

  shared_examples "restricted review queue counters" do |kind|
    it "[cr-u1] performs an ordinary reviewable action without queue counts with #{kind} active" do
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

  include_examples "restricted review queue counters", "PM-off"
  include_examples "restricted review queue counters", "an unrelated rule"

  it "[cr-u1] preserves reviewable action queue counts including PM reviewables without rule rows" do
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

  shared_examples "PM bookmark summary counts" do |bookmark_type|
    it "[cr-u1] excludes a sole PM #{bookmark_type} bookmark from get_user_summary under PM-off" do
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

    it "[cr-u1] counts a sole PM #{bookmark_type} bookmark in get_user_summary without rule rows" do
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

  it "[cr-u1] retains public topic and post bookmarks while excluding both PM bookmark types under PM-off" do
    message = Fabricate(:private_message_post, user: admin)
    public_post = Fabricate(:post, user: admin)
    [message.topic, message, public_post.topic, public_post].each do |bookmarkable|
      Fabricate(:bookmark, user: admin, bookmarkable:)
    end
    Fabricate(:topic_user, user: admin, topic: message.topic)
    Fabricate(:topic_user, user: admin, topic: public_post.topic)
    expect(
      content(tool("discourse_get_user_summary", username: admin.username)).fetch(:bookmark_count),
    ).to eq(4)
    activate_rule("PM-off")

    result = content(tool("discourse_get_user_summary", username: admin.username))

    expect(result.fetch(:bookmark_count)).to eq(2)
  end
end
