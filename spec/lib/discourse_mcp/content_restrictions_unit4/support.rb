# frozen_string_literal: true

module McpContentRestrictionsUnit4
  GENERIC_ERROR = "The operation could not be completed with these parameters"
  PROSE = "An ordinary discussion of gardens and changing seasons."
  LABELLED_LINK =
    "Please consult [the documentation](https://external.example/page) for further details."
  MISSING_ID = 93_400_999

  def issue_token(user = admin)
    unless user.admin?
      DiscourseMcp.registry.scopes.each do |scope|
        McpGroupScope.find_or_create_by!(
          group_id: Group::AUTO_GROUPS[:logged_in_users],
          scope: scope,
        )
      end
    end
    client =
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Unit four write oracle",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )
    authorization =
      DiscourseMcp::OAuth::AuthorizationGrant.create!(
        user: user,
        client: client,
        redirect_uri: client.redirect_uris.first,
        requested_scopes: DiscourseMcp.registry.scopes,
      )
    raw_token = McpOauthAccessToken.issue!(authorization: authorization)
    McpOauthAccessToken.find_by!(token_hash: McpOauthAccessToken.digest(raw_token))
  end

  def rpc(name, arguments, access_token: token)
    McpPrimitive.find_or_create_by!(kind: "tool", identifier: name).update!(enabled: true)
    request = ActionDispatch::TestRequest.create
    request.headers["MCP-Protocol-Version"] = DiscourseMcp::LEGACY_PROTOCOL_VERSION
    response =
      DiscourseMcp::Server.new(
        request: request,
        request_context: DiscourseMcp::RequestContext.new(access_token),
      ).call(
        "jsonrpc" => "2.0",
        "id" => 4,
        "method" => "tools/call",
        "params" => {
          "name" => name,
          "arguments" => arguments.deep_stringify_keys,
        },
      )
    Scheduler::Defer.do_all_work
    JSON.parse(
      JSON.generate(status: response.http_status, headers: response.headers, body: response.body),
    )
  end

  def result(response)
    response.fetch("body").fetch("result")
  end

  def expect_success(response)
    expect(response["status"]).to eq(200), "MCP SUCCESS status: #{response.inspect}"
    expect(response.dig("body", "error")).to be_nil,
    "MCP SUCCESS protocol error: #{response.inspect}"
    expect(result(response)["isError"]).not_to eq(true),
    "MCP SUCCESS tool error: #{response.inspect}"
    result(response).fetch("structuredContent")
  end

  def expect_refusal(response)
    expect(response.dig("body", "result", "isError")).to eq(true),
    "WRITE REFUSAL: expected isError=true, received #{response.inspect}"
    return unless response.dig("body", "result", "isError") == true

    expect(response["status"]).to eq(200)
    error = result(response)
    expect(error["structuredContent"]).to be_nil
    expect(error.fetch("content").size).to eq(1)
    expect(error.fetch("content").first.fetch("type")).to eq("text")
    expect(error.fetch("content").first.fetch("text")).to be_present
  end

  def expect_reference_refusal(response)
    expect_refusal(response)
    return unless response.dig("body", "result", "isError") == true

    expect(response).to eq(reference_error),
    "REFERENCE ERROR: rejected forms must have one identical envelope"
  end

  def reference_error
    @reference_error ||=
      begin
        response = nil
        isolated(clear_jobs: false) do
          upload = Fabricate(:upload, user: admin)
          response =
            rpc("discourse_update_user", { username: admin.username, upload_id: upload.id })
        end
        expect_refusal(response)
        response
      end
  end

  def activate!(kind = :forum)
    McpContentRule.delete_all
    if kind == :pm
      McpContentRule.create!(rule_kind: "private_messages", config: {})
    else
      McpContentRule.create!(
        rule_kind: "forum_content",
        config: {
          allow: {
            mode: "all",
            category_ids: [],
            tag_ids: [],
          },
          deny: {
            category_ids: [restricted_category.id],
            tag_ids: [denied_tag.id],
          },
        },
      )
    end
    @reference_error = nil
  end

  def isolated(clear_jobs: true)
    ActiveRecord::Base.transaction(requires_new: true) do
      yield
      raise ActiveRecord::Rollback
    end
  ensure
    Sidekiq::Worker.clear_all if clear_jobs
  end

  def topic_arguments(raw: PROSE, title: "A thoughtful discussion about seasonal gardens", **extra)
    { title: title, raw: raw, category_id: allowed_category.id }.merge(extra)
  end

  def content_state
    {
      posts:
        Post
          .with_deleted
          .order(:id)
          .pluck(
            :id,
            :raw,
            :cooked,
            :deleted_at,
            :user_deleted,
            :hidden,
            :version,
            :edit_reason,
            :baked_at,
            :baked_version,
          ),
      topics:
        Topic.with_deleted.order(:id).pluck(:id, :title, :category_id, :deleted_at, :featured_link),
      topic_tags: TopicTag.order(:topic_id, :tag_id).pluck(:topic_id, :tag_id),
      categories: Category.order(:id).pluck(:id, :name, :description, :parent_category_id, :slug),
      groups:
        Group.order(:id).pluck(
          :id,
          :name,
          :full_name,
          :bio_raw,
          :bio_cooked,
          :membership_request_template,
          :title,
        ),
      profiles:
        UserProfile.order(:user_id).pluck(
          :user_id,
          :bio_raw,
          :bio_cooked,
          :location,
          :website,
          :profile_background_upload_id,
          :card_background_upload_id,
        ),
      users:
        User.order(:id).pluck(
          :id,
          :name,
          :title,
          :suspended_till,
          :silenced_till,
          :uploaded_avatar_id,
        ),
      requests: GroupRequest.order(:id).pluck(:id, :reason),
      drafts: Draft.order(:id).pluck(:id, :data, :sequence),
      reviewables: Reviewable.order(:id).pluck(:id, :status, :payload),
      invites: Invite.order(:id).pluck(:id, :custom_message),
      statuses: UserStatus.order(:user_id).pluck(:user_id, :description),
      uploads: Upload.order(:id).pluck(:id, :secure, :access_control_post_id, :url),
      upload_references: UploadReference.order(:id).pluck(:upload_id, :target_type, :target_id),
    }
  end

  def assert_reference_write(name, arguments)
    before_state = content_state
    response = rpc(name, arguments)
    aggregate_failures do
      expect_reference_refusal(response)
      expect(content_state).to eq(before_state),
      "WRITE ATOMICITY: refused reference persisted content"
    end
  end
end

RSpec.shared_context "with unit four MCP writes" do
  include McpContentRestrictionsUnit4

  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:recipient, :user)
  fab!(:allowed_category) { Fabricate(:category, user: admin) }
  fab!(:restricted_category) { Fabricate(:category, user: admin) }
  fab!(:denied_tag) { Fabricate(:tag, name: "u4-denied") }
  fab!(:post) do
    Fabricate(
      :post,
      user: admin,
      topic: Fabricate(:topic, user: admin, category: allowed_category),
      raw: McpContentRestrictionsUnit4::PROSE,
    )
  end
  let(:token) { issue_token }

  before do
    McpContentRule.delete_all
    SiteSetting.mcp_server_enabled = true
    SiteSetting.tagging_enabled = true
    SiteSetting.authorized_extensions = "txt|png|svg"
    SiteSetting.allow_duplicate_topic_titles = true
    SiteSetting.allow_new_registrations = true
    SiteSetting.min_first_post_length = 1
    SiteSetting.min_post_length = 1
    SiteSetting.min_personal_message_post_length = 1
    SiteSetting.enable_user_status = true
    SiteSetting.embedded_media_post_allowed_groups = Group::AUTO_GROUPS[:everyone].to_s
    Jobs.run_later!
    token
    Sidekiq::Worker.clear_all
  end
end
