# frozen_string_literal: true

RSpec.describe "Shared AI profile inspection" do
  fab!(:owner) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:llm_model)
  fab!(:agent) { Fabricate(:ai_agent, default_llm: llm_model).tap(&:ensure_user!) }
  fab!(:topic) { Fabricate(:private_message_topic, user: owner, recipient: agent.user) }
  fab!(:source_post) { Fabricate(:post, topic: topic, user: owner) }
  fab!(:artifact) { Fabricate(:ai_artifact, post: source_post, user: owner) }

  let(:artifact_path) { "/discourse-ai/ai-bot/artifact-shares" }
  let(:conversation_path) { "/discourse-ai/ai-bot/shared-ai-conversations" }
  let(:paths) { [artifact_path, conversation_path] }
  let(:share) do
    AiArtifactShare
      .new(ai_artifact: artifact, user: owner)
      .tap { |record| record.pin!(version_number: 0) }
  end
  let(:conversation) { SharedAiConversation.share_conversation(owner, topic) }

  before do
    enable_current_plugin
    SiteSetting.ai_artifact_security = "strict"
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [llm_model])
    group.add(owner)
    SiteSetting.ai_bot_public_sharing_allowed_groups = group.id.to_s
    source_post.update_columns(
      cooked: "<div class='ai-artifact' data-ai-artifact-id='#{artifact.id}'></div>",
    )
  end

  it "requires login for both target feeds" do
    paths.each do |path|
      get "#{path}.json", params: { user_id: owner.id }
      expect(response).to have_http_status(:forbidden)
    end
  end

  it "refuses unrelated users and moderators on both feeds, including cursors" do
    [Fabricate(:user), Fabricate(:moderator)].each do |viewer|
      sign_in(viewer)
      paths.each do |path|
        get "#{path}.json", params: { user_id: owner.id, cursor: "{}" }
        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body["items"]).to be_nil
      end
    end
  end

  it "allows explicit self targets and keeps owner management" do
    share
    conversation
    sign_in(owner)

    paths.each do |path|
      get "#{path}.json", params: { user_id: owner.id }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.slice("user_id", "can_manage")).to eq(
        "user_id" => owner.id,
        "can_manage" => true,
      )
      expect(response.parsed_body["items"]).to be_present
      expect(response.parsed_body["items"].first).to have_key("share_key")
    end
  end

  it "returns only published representation fields to an administrator" do
    share
    conversation
    original_name = share.name
    artifact.update!(name: "Private renamed source", html: "<p>Private unpublished revision</p>")
    private_post = Fabricate(:post, topic: topic, user: owner, raw: "Unpublished private post")
    unshared = Fabricate(:ai_artifact, post: private_post, user: owner)
    storage =
      Fabricate(
        :ai_artifact_key_value,
        ai_artifact: artifact,
        user: owner,
        value: "Private storage",
      )
    sign_in(admin)

    get "#{artifact_path}.json", params: { user_id: owner.id }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.slice("user_id", "can_manage")).to eq(
      "user_id" => owner.id,
      "can_manage" => false,
    )
    items = response.parsed_body["items"]
    expect(items.map { |item| [item["type"], item["name"], item["url"]] }).to contain_exactly(
      ["standalone", original_name, share.url],
      ["conversation", conversation.title, conversation.url],
    )
    items.each do |item|
      expect(item.keys - %w[id type name url version created_at available]).to eq([])
    end
    expect(response.body).not_to include(
      artifact.name,
      artifact.html,
      private_post.raw,
      unshared.name,
      storage.value,
    )

    get "#{conversation_path}.json", params: { user_id: owner.id }
    expect(response.parsed_body["items"]).to eq(
      [
        {
          "id" => conversation.id,
          "title" => conversation.title,
          "url" => conversation.url,
          "created_at" => conversation.created_at.as_json,
          "available" => true,
        },
      ],
    )
    expect(response.body).not_to include(private_post.raw, storage.value, conversation.excerpt)
  end

  it "lists a conversation publication once during inspection while preserving owner artifact cards" do
    second_artifact = Fabricate(:ai_artifact, post: source_post, user: owner)
    third_artifact = Fabricate(:ai_artifact, post: source_post, user: owner)
    artifacts = [artifact, second_artifact, third_artifact]
    source_post.update_columns(
      cooked:
        artifacts
          .map { |source| "<div class='ai-artifact' data-ai-artifact-id='#{source.id}'></div>" }
          .join,
    )
    conversation
    artifact.reload.update!(metadata: { public: false })
    sign_in(admin)

    %w[newest oldest].each do |order|
      get "#{artifact_path}.json", params: { user_id: owner.id, type: "conversation", order: order }
      expect(response).to have_http_status(:ok)
      expect(
        response.parsed_body["items"].map { |item| item.slice("id", "name", "url", "available") },
      ).to eq(
        [
          {
            "id" => "conversation-#{conversation.id}",
            "name" => conversation.title,
            "url" => conversation.url,
            "available" => true,
          },
        ],
      )
    end

    sign_in(owner)
    get "#{artifact_path}.json", params: { type: "conversation" }
    expect(
      response.parsed_body["items"].map { |item| [item["id"], item["name"], item["available"]] },
    ).to eq(
      artifacts.map do |source|
        ["conversation-#{conversation.id}-#{source.id}", source.name, source != artifact]
      end,
    )
  end

  it "preserves the existing administrator conversation DELETE API despite read-only inspection controls" do
    conversation
    sign_in(admin)
    get "#{conversation_path}.json", params: { user_id: owner.id }
    expect(response.parsed_body["can_manage"]).to eq(false)
    expect(response.parsed_body["items"].sole["url"]).to include(conversation.share_key)

    delete "#{conversation_path}/#{conversation.share_key}.json"
    expect(response).to have_http_status(:ok)
    expect(SharedAiConversation.exists?(conversation.id)).to eq(false)
  end

  it "evaluates publication against the owner even when the administrator may publish" do
    share
    conversation
    group.remove(owner)
    group.add(admin)
    sign_in(admin)

    paths.each do |path|
      get "#{path}.json", params: { user_id: owner.id }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["items"]).to eq([])
    end
  end

  it "excludes unavailable publications while retaining them for owner revocation" do
    share
    conversation
    source_post.trash!
    sign_in(admin)
    paths.each do |path|
      get "#{path}.json", params: { user_id: owner.id }
      expect(response.parsed_body["items"]).to eq([])
    end

    sign_in(owner)
    paths.each do |path|
      get "#{path}.json", params: { user_id: owner.id }
      expect(response.parsed_body["items"]).to be_present
      expect(response.parsed_body["items"].pluck("available").uniq).to eq([false])
    end
    delete "#{artifact_path}/#{share.share_key}.json"
    expect(response).to have_http_status(:no_content)
    delete "#{conversation_path}/#{conversation.share_key}.json"
    expect(response).to have_http_status(:ok)
  end

  it "excludes orphaned and disabled publications rather than using administrator source access" do
    share
    conversation
    sign_in(admin)
    SiteSetting.ai_bot_enabled = false
    paths.each do |path|
      get "#{path}.json", params: { user_id: owner.id }
      expect(response.parsed_body["items"]).to eq([])
    end

    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_artifact_security = "disabled"
    get "#{artifact_path}.json", params: { user_id: owner.id }
    expect(response.parsed_body["items"]).to eq([])
    SiteSetting.ai_artifact_security = "strict"
    Topic.where(id: topic.id).delete_all
    paths.each do |path|
      get "#{path}.json", params: { user_id: owner.id }
      expect(response.parsed_body["items"]).to eq([])
    end
  end

  it "requires a valid existing target and respects the plugin enablement gate" do
    sign_in(admin)
    paths.each do |path|
      ["", "bad", "#{owner.id}suffix", "999999999999", [owner.id]].each do |target|
        get "#{path}.json", params: { user_id: target }
        expect(response).to have_http_status(:bad_request)
      end
      get "#{path}.json", params: { user_id: User.maximum(:id) + 1 }
      expect(response).to have_http_status(:forbidden)
      get "#{path}.json", params: { user_id: "9999999999" }
      expect(response).to have_http_status(:forbidden)
    end

    SiteSetting.discourse_ai_enabled = false
    paths.each do |path|
      get "#{path}.json", params: { user_id: owner.id }
      expect(response).to have_http_status(:not_found)
    end
  end

  it "keeps the target and publication boundary through artifact filtering and pagination in both directions" do
    conversation
    shares =
      22.times.map do
        source = Fabricate(:ai_artifact, post: source_post, user: owner)
        AiArtifactShare
          .new(ai_artifact: source, user: owner)
          .tap { |record| record.pin!(version_number: 0) }
      end
    admin_source = Fabricate(:ai_artifact, user: admin)
    admin_share = AiArtifactShare.new(ai_artifact: admin_source, user: admin)
    admin_share.pin!(version_number: 0)
    sign_in(admin)

    %w[newest oldest].each do |order|
      get "#{artifact_path}.json", params: { user_id: owner.id, type: "standalone", order: order }
      page = response.parsed_body
      expect(page["items"].size).to eq(20)
      expect(page["has_more"]).to eq(true)
      urls = page["items"].pluck("url")
      get "#{artifact_path}.json",
          params: {
            user_id: owner.id,
            type: "standalone",
            order: order,
            cursor: page["next_cursor"].to_json,
          }
      expect(response).to have_http_status(:ok)
      expect(urls + response.parsed_body["items"].pluck("url")).to match_array(shares.map(&:url))
      expect(response.parsed_body["has_more"]).to eq(false)
    end

    get "#{artifact_path}.json", params: { user_id: owner.id, type: "conversation" }
    expect(response.parsed_body["items"].pluck("url")).to eq([conversation.url])
    get "#{artifact_path}.json"
    expect(response.parsed_body["items"].pluck("url")).to eq([admin_share.url])
  end

  it "continues past empty bounded inspection pages without exposing unavailable labels" do
    shares =
      101.times.map do |index|
        AiArtifactShare.create!(
          ai_artifact_id: artifact.id + index + 1,
          user: owner,
          name: "Orphan #{index}",
        )
      end
    sign_in(admin)
    get "#{artifact_path}.json", params: { user_id: owner.id, type: "standalone" }
    page = response.parsed_body
    expect(page["items"]).to eq([])
    expect(page["has_more"]).to eq(true)
    expect(response.body).not_to include(shares.first.name)
    get "#{artifact_path}.json",
        params: {
          user_id: owner.id,
          type: "standalone",
          cursor: page["next_cursor"].to_json,
        }
    expect(response.parsed_body["items"]).to eq([])
    expect(response.parsed_body["has_more"]).to eq(false)
  end

  it "paginates available conversation publications in both directions without changing owners" do
    snapshots =
      22.times.map do |index|
        shared_topic = Fabricate(:private_message_topic, user: owner, recipient: agent.user)
        shared_post = Fabricate(:post, topic: shared_topic, user: owner)
        SharedAiConversation.create!(
          user: owner,
          target: shared_topic,
          title: "Published #{index}",
          llm_name: "Bot",
          excerpt: shared_post.excerpt,
          context: [{ id: shared_post.id, cooked: shared_post.cooked }],
        )
      end
    sign_in(admin)
    %w[newest oldest].each do |order|
      get "#{conversation_path}.json", params: { user_id: owner.id, order: order }
      page = response.parsed_body
      expect(page["items"].size).to eq(20)
      expect(page["can_manage"]).to eq(false)
      expect(page["has_more"]).to eq(true)
      get "#{conversation_path}.json",
          params: {
            user_id: owner.id,
            order: order,
            cursor: page["next_cursor"].to_json,
          }
      expect(response).to have_http_status(:ok)
      items = page["items"] + response.parsed_body["items"]
      expected = order == "newest" ? snapshots.reverse : snapshots
      expect(items.pluck("url")).to eq(expected.map(&:url))
      expect(items.all? { |item| item["available"] && !item.key?("share_key") }).to eq(true)
      expect(response.parsed_body["has_more"]).to eq(false)
    end
  end

  it "keeps unavailable conversation pages bounded and scoped to the inspected owner" do
    snapshots =
      22.times.map do |index|
        SharedAiConversation.create!(
          user: owner,
          target: Fabricate(:private_message_topic, user: owner, recipient: agent.user),
          title: "Withdrawn #{index}",
          llm_name: "Bot",
          excerpt: "Withdrawn excerpt",
          context: [{ id: source_post.id, cooked: source_post.cooked }],
        )
      end
    sign_in(admin)
    %w[newest oldest].each do |order|
      get "#{conversation_path}.json", params: { user_id: owner.id, order: order }
      page = response.parsed_body
      expect(page["items"]).to eq([])
      expect(page["has_more"]).to eq(true)
      expect(response.body).not_to include(snapshots.first.title)
      get "#{conversation_path}.json",
          params: {
            user_id: owner.id,
            order: order,
            cursor: page["next_cursor"].to_json,
          }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["items"]).to eq([])
      expect(response.parsed_body["has_more"]).to eq(false)
    end
  end

  it "does not grant artifact update, publication or revoke powers during inspection" do
    share
    sign_in(admin)
    get "#{artifact_path}.json", params: { user_id: owner.id }
    expect(response.parsed_body["can_manage"]).to eq(false)
    put "#{artifact_path}/#{share.share_key}.json", params: { user_id: owner.id, version: 0 }
    expect(response).to have_http_status(:not_found)
    delete "#{artifact_path}/#{share.share_key}.json", params: { user_id: owner.id }
    expect(response).to have_http_status(:not_found)
    post "#{artifact_path}/#{artifact.id}.json", params: { user_id: owner.id, version: 0 }
    expect(response).to have_http_status(:not_found)
    expect(share.reload.user_id).to eq(owner.id)
  end
end
