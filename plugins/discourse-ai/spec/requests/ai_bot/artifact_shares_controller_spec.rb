# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::ArtifactSharesController do
  fab!(:owner) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:llm_model) { Fabricate(:llm_model, name: "artifact-sharing-model") }
  fab!(:agent) { Fabricate(:ai_agent, default_llm: llm_model).tap(&:ensure_user!) }
  fab!(:topic) { Fabricate(:private_message_topic, user: owner) }
  fab!(:source_post) { Fabricate(:post, topic: topic, user: owner) }
  fab!(:artifact) { Fabricate(:ai_artifact, post: source_post, user: owner) }

  let(:base_path) { "/discourse-ai/ai-bot/artifact-shares" }
  let(:bot_user) { agent.user }

  before do
    enable_current_plugin
    SiteSetting.ai_artifact_security = "strict"
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_public_sharing_allowed_groups = "10"
    toggle_enabled_bots(bots: [llm_model])
    topic.topic_allowed_users.where.not(user_id: owner.id).delete_all
    topic.topic_allowed_users.create!(user: bot_user)
    Group.user_trust_level_change!(owner.id, owner.trust_level)
  end

  it "keeps the global login wall for a valid standalone share key" do
    share = AiArtifactShare.new(ai_artifact: artifact, user: owner)
    share.pin!(version_number: 0)
    SiteSetting.login_required = true

    get "#{base_path}/#{share.share_key}"
    expect(response).to redirect_to("/login")
  end

  it "lists disabled shares for revocation, refuses publication, and never revives revoked keys" do
    source_post.update_columns(
      cooked: "<div class='ai-artifact' data-ai-artifact-id='#{artifact.id}'></div>",
    )
    conversation = SharedAiConversation.share_conversation(owner, topic)
    sign_in(owner)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    key = response.parsed_body["share_key"]

    SiteSetting.ai_artifact_security = "disabled"
    get "#{base_path}.json"
    expect(response.status).to eq(200)
    expect(
      response.parsed_body["items"].map { |item| [item["type"], item["available"]] },
    ).to contain_exactly(["standalone", false], ["conversation", false])
    get "#{base_path}/eligibility/#{artifact.id}.json"
    expect(response.status).to eq(404)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    expect(response.status).to eq(404)
    get "#{base_path}/#{key}"
    expect(response.status).to eq(404)
    get AiArtifact.embed_url(artifact.id)
    expect(response.status).to eq(404)
    sign_in(owner)
    delete "#{base_path}/#{key}.json"
    expect(response.status).to eq(204)

    SiteSetting.ai_artifact_security = "strict"
    get "#{base_path}/#{key}"
    expect(response.status).to eq(404)
    get "#{base_path}.json"
    expect(response.parsed_body["items"].map { |item| item["type"] }).to eq(["conversation"])
    expect(response.parsed_body["items"].first["available"]).to eq(true)
    expect(response.parsed_body["items"].first["embed_url"]).to eq(
      AiArtifact.embed_url(artifact.id),
    )
    expect(conversation.reload).to be_present
  end

  it "blocks a conversation embed after sharing, group membership, or source visibility is revoked" do
    source_post.update_columns(
      cooked: "<div class='ai-artifact' data-ai-artifact-id='#{artifact.id}'></div>",
    )
    conversation = SharedAiConversation.share_conversation(owner, topic)
    sign_in(owner)
    get AiArtifact.embed_url(artifact.id)
    expect(response.status).to eq(200)

    SiteSetting.ai_bot_public_sharing_allowed_groups = "1"
    get AiArtifact.embed_url(artifact.id)
    expect(response.status).to eq(404)
    SiteSetting.ai_bot_public_sharing_allowed_groups = "10"
    group = Fabricate(:group)
    group.add(owner)
    SiteSetting.ai_bot_public_sharing_allowed_groups = group.id.to_s
    get AiArtifact.embed_url(artifact.id)
    expect(response.status).to eq(200)
    group.remove(owner)
    get AiArtifact.embed_url(artifact.id)
    expect(response.status).to eq(404)
    SiteSetting.ai_bot_public_sharing_allowed_groups = "10"
    topic.topic_allowed_users.create!(user: Fabricate(:user))
    get AiArtifact.embed_url(artifact.id)
    expect(response.status).to eq(404)
    topic.topic_allowed_users.last.destroy!
    source_post.trash!
    get AiArtifact.embed_url(artifact.id)
    expect(response.status).to eq(404)
    source_post.recover!
    SharedAiConversation.destroy_conversation(conversation)
    get AiArtifact.embed_url(artifact.id)
    expect(response.status).to eq(404)
  end

  it "pins the base content for a guest without granting access to ID, versions, or key values" do
    sign_in(owner)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    expect(response.status).to eq(201)
    key = response.parsed_body["share_key"]
    pinned_html = artifact.html

    artifact.update!(html: "<p>Private future content</p>")
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    expect(response.parsed_body["share_key"]).to eq(key)
    expect(response.status).to eq(200)
    future_version = artifact.create_new_version(html: "<p>Private future version</p>")
    sign_out

    get "#{base_path}/#{key}"
    expect(response.status).to eq(200)
    frame = Nokogiri.HTML5(response.body).at_css("iframe")
    expect(frame["sandbox"]).to eq("allow-scripts allow-forms")
    expect(response.headers["Referrer-Policy"]).to eq("no-referrer")
    expect(frame["srcdoc"]).to include(pinned_html)
    expect(frame["srcdoc"]).to include("window.discourseArtifactReady = Promise.resolve")
    expect(frame["srcdoc"]).to include("window.discourseArtifact = {")
    expect(frame["srcdoc"]).to include("Key-value storage is unavailable in public shares")
    expect(frame["srcdoc"]).not_to include("_discourse_user_data", "_postMessageRequest")
    expect(frame["srcdoc"]).not_to include(artifact.html, future_version.html)
    expect(response.body).not_to include(
      "discourse-artifact-kv",
      "csrf-token",
      "_discourse_user_data",
    )

    get artifact.url
    expect(response.status).to eq(404)
    get AiArtifact.url(artifact.id, future_version.version_number)
    expect(response.status).to eq(404)
    get "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}.json"
    expect(response.status).not_to eq(200)
  end

  it "pins an explicit version and updates only on an owner's explicit request" do
    first = artifact.create_new_version(html: "<p>First version</p>")
    second = artifact.create_new_version(html: "<p>Second version</p>")
    sign_in(owner)

    post "#{base_path}/#{artifact.id}.json", params: { version: first.version_number }
    key = response.parsed_body["share_key"]
    get "#{base_path}/#{key}"
    expect(Nokogiri.HTML5(response.body).at_css("iframe")["srcdoc"]).to include(first.html)

    put "#{base_path}/#{key}.json", params: { version: second.version_number }
    expect(response.status).to eq(200)
    get "#{base_path}/#{key}"
    expect(Nokogiri.HTML5(response.body).at_css("iframe")["srcdoc"]).to include(second.html)

    put "#{base_path}/#{key}.json", params: { version: 999 }
    expect(response.status).to eq(404)

    third = artifact.create_new_version(html: "<p>Third version</p>")
    put "#{base_path}/#{key}.json"
    expect(response.status).to eq(404)
    get "#{base_path}/#{key}"
    expect(Nokogiri.HTML5(response.body).at_css("iframe")["srcdoc"]).to include(second.html)

    put "#{base_path}/#{key}.json", params: { version: first.version_number }
    expect(response.parsed_body["version"]).to eq(first.version_number)
    get "#{base_path}/#{key}"
    expect(Nokogiri.HTML5(response.body).at_css("iframe")["srcdoc"]).to include(first.html)
    expect(Nokogiri.HTML5(response.body).at_css("iframe")["srcdoc"]).not_to include(third.html)

    put "#{base_path}/#{key}.json", params: { version: 0 }
    expect(response.parsed_body["version"]).to eq(0)
  end

  it "requires an explicit existing version when creating and updating a link" do
    sign_in(owner)
    post "#{base_path}/#{artifact.id}.json"
    expect(response.status).to eq(404)
    expect(AiArtifactShare.where(ai_artifact: artifact, user: owner)).not_to exist

    post "#{base_path}/#{artifact.id}.json", params: { version: "00" }
    expect(response.status).to eq(404)
    post "#{base_path}/#{artifact.id}.json", params: { version: 999 }
    expect(response.status).to eq(404)
    post "#{base_path}/#{artifact.id}.json", params: { version: "9999999999999999999999999" }
    expect(response.status).to eq(404)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    expect(response.status).to eq(201)
    expect(response.parsed_body["version"]).to eq(0)
  end

  it "rejects other users and revokes only the standalone link" do
    sign_in(owner)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    key = response.parsed_body["share_key"]
    other_user = Fabricate(:user)
    topic.topic_allowed_users.create!(user: other_user)
    sign_in(other_user)

    get "#{base_path}/eligibility/#{artifact.id}.json"
    expect(response.parsed_body["can_share"]).to eq(false)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    expect(response.status).to eq(404)
    put "#{base_path}/#{key}.json"
    expect(response.status).to eq(404)
    delete "#{base_path}/#{key}.json"
    expect(response.status).to eq(404)
    get "#{base_path}.json"
    expect(response.parsed_body["items"]).to eq([])

    sign_in(owner)
    delete "#{base_path}/#{key}.json"
    expect(response.status).to eq(204)
    sign_out
    get "#{base_path}/#{key}"
    expect(response.status).to eq(404)
  end

  it "permits the PM creator to share a bot-owned artifact without publishing conversation context" do
    artifact.update!(user: bot_user)
    sign_in(owner)
    get "#{base_path}/eligibility/#{artifact.id}.json"
    expect(response.parsed_body["can_share"]).to eq(true)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    expect(response.status).to eq(201)
    sign_out
    get "#{base_path}/#{response.parsed_body["share_key"]}"
    expect(response.status).to eq(200)
    expect(response.body).not_to include(source_post.raw)
  end

  it "permits the PM creator to share an artifact owned by a detached legacy bot" do
    legacy_bot = Fabricate(:user, id: DiscourseAi::BotUser.next_id)
    UserCustomField.create!(
      user: legacy_bot,
      name: DiscourseAi::AiBot::HISTORICAL_AI_USER_CUSTOM_FIELD,
      value: "true",
    )
    topic.topic_allowed_users.where.not(user_id: owner.id).delete_all
    topic.topic_allowed_users.create!(user: legacy_bot)
    artifact.update!(user: legacy_bot)
    sign_in(owner)

    get "#{base_path}/eligibility/#{artifact.id}.json"
    expect(response.parsed_body["can_share"]).to eq(true)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    expect(response).to have_http_status(:created)
    expect(AiArtifactShare.find_by!(ai_artifact: artifact, user: owner).share_key).to eq(
      response.parsed_body["share_key"],
    )
  end

  it "keeps a standalone snapshot after conversation access is revoked" do
    topic.topic_allowed_users.where.not(user_id: owner.id).delete_all
    topic.topic_allowed_users.create!(user: bot_user)
    second_artifact =
      Fabricate(:ai_artifact, user: owner, post: source_post, name: "Another artifact")
    source_post.update_columns(
      cooked:
        "<div class='ai-artifact' data-ai-artifact-id='#{artifact.id}'></div>" \
          "<div class='ai-artifact' data-ai-artifact-id='#{second_artifact.id}'></div>",
    )

    conversation = SharedAiConversation.share_conversation(owner, topic)
    sign_in(owner)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    key = response.parsed_body["share_key"]
    20.times do |index|
      extra_artifact =
        Fabricate(:ai_artifact, user: owner, post: source_post, name: "Extra #{index}")
      AiArtifactShare.new(ai_artifact: extra_artifact, user: owner).pin!(version_number: 0)
    end
    get "#{base_path}.json"
    expect(response.parsed_body["items"].length).to eq(20)
    expect(response.parsed_body["has_more"]).to eq(true)
    cursor = response.parsed_body["next_cursor"]
    get "#{base_path}.json", params: { cursor: cursor.to_json }
    expect(response.parsed_body["items"].map { |item| item["name"] }).to contain_exactly(
      artifact.name,
      second_artifact.name,
      artifact.name,
    )
    expect(response.parsed_body["items"].map { |item| item["type"] }).to contain_exactly(
      "standalone",
      "conversation",
      "conversation",
    )
    expect(response.parsed_body["has_more"]).to eq(false)

    delete "#{base_path}/#{key}.json"
    expect(response.status).to eq(204)
    get conversation.url
    expect(response.status).to eq(200)

    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    key = response.parsed_body["share_key"]
    delete "/discourse-ai/ai-bot/shared-ai-conversations/#{conversation.share_key}.json"
    expect(response.status).to eq(200)
    get "#{base_path}.json"
    expect(response.parsed_body["items"].map { |item| item["type"] }).to all(eq("standalone"))
    sign_out
    get "#{base_path}/#{key}"
    expect(response.status).to eq(200)
    get artifact.url
    expect(response.status).to eq(404)
  end

  it "paginates the owner's standalone links and rejects access after losing post visibility" do
    sign_in(owner)
    21.times do |index|
      extra_artifact =
        Fabricate(:ai_artifact, user: owner, post: source_post, name: "Artifact #{index}")
      AiArtifactShare.new(ai_artifact: extra_artifact, user: owner).pin!(version_number: 0)
    end

    get "#{base_path}.json"
    first_page = response.parsed_body
    expect(first_page["items"].length).to eq(20)
    expect(first_page["has_more"]).to eq(true)
    expect(first_page["items"].map { |item| item["id"] }.uniq.length).to eq(20)
    get "#{base_path}.json", params: { cursor: first_page["next_cursor"].to_json }
    expect(response.parsed_body["items"].map { |item| item["name"] }).to eq(["Artifact 0"])
    expect(response.parsed_body["has_more"]).to eq(false)
    expect(response.parsed_body["next_cursor"]).to be_nil
    get "#{base_path}.json", params: { order: "oldest" }
    expect(response.parsed_body["items"].first["name"]).to eq("Artifact 0")
    get "#{base_path}.json", params: { order: "newest" }
    expect(response.parsed_body["items"].first["name"]).to eq("Artifact 20")

    topic.topic_allowed_users.where(user_id: owner.id).delete_all
    topic.trash!
    get "#{base_path}/eligibility/#{artifact.id}.json"
    expect(response.parsed_body["can_share"]).to eq(false)
  end

  it "paginates conversations by conversation rather than by the number of artifact cards" do
    21.times do |index|
      conversation_topic = Fabricate(:private_message_topic, user: owner, recipient: bot_user)
      conversation_post = Fabricate(:post, topic: conversation_topic, user: owner)
      conversation_artifact =
        Fabricate(:ai_artifact, post: conversation_post, user: owner, name: "Card #{index}")
      conversation_post.update_columns(
        cooked: "<div class='ai-artifact' data-ai-artifact-id='#{conversation_artifact.id}'></div>",
      )
      SharedAiConversation.share_conversation(owner, conversation_topic)
    end
    sign_in(owner)

    queries = track_sql_queries { get "#{base_path}.json", params: { type: "conversation" } }
    expect(queries.size).to be <= 210
    first_page = response.parsed_body
    expect(first_page["items"].length).to eq(20)
    expect(first_page["has_more"]).to eq(true)
    expect(first_page["items"].first["name"]).to eq("Card 20")
    get "#{base_path}.json",
        params: {
          type: "conversation",
          cursor: first_page["next_cursor"].to_json,
        }
    expect(response.parsed_body["items"].map { |item| item["name"] }).to eq(["Card 0"])
    expect(response.parsed_body["has_more"]).to eq(false)
    get "#{base_path}.json", params: { type: "conversation", order: "oldest" }
    expect(response.parsed_body["items"].first["name"]).to eq("Card 0")

    oldest_conversation = SharedAiConversation.where(user: owner).order(:created_at, :id).first
    original_context = oldest_conversation.context
    oldest_conversation.update_columns(
      context: [{ "id" => original_context.first["id"], "cooked" => "No artifact" }],
    )
    get "#{base_path}.json", params: { type: "conversation" }
    expect(response.parsed_body["items"].length).to eq(20)
    expect(response.parsed_body["has_more"]).to eq(true)
    get "#{base_path}.json",
        params: {
          type: "conversation",
          cursor: response.parsed_body["next_cursor"].to_json,
        }
    expect(response.parsed_body["items"]).to eq([])
    expect(response.parsed_body["has_more"]).to eq(false)
    oldest_conversation.update_columns(context: original_context)

    SharedAiConversation
      .where(user: owner)
      .order(created_at: :desc, id: :desc)
      .limit(20)
      .each do |conversation|
        conversation.update_columns(
          context: [{ "id" => conversation.context.first["id"], "cooked" => "No artifact" }],
        )
      end
    get "#{base_path}.json", params: { type: "conversation" }
    expect(response.parsed_body["items"].map { |item| item["name"] }).to eq(["Card 0"])
    expect(response.parsed_body["has_more"]).to eq(false)
  end

  it "bounds scans of empty conversation snapshots while providing a cursor to later cards" do
    101.times do |index|
      empty_topic = Fabricate(:private_message_topic, user: owner, recipient: bot_user)
      empty_post = Fabricate(:post, topic: empty_topic, user: owner)
      empty_post.update_columns(cooked: "No artifact #{index}")
      SharedAiConversation.create!(
        user: owner,
        target: empty_topic,
        title: empty_topic.title,
        llm_name: "Bot",
        excerpt: "No artifact",
        context: [{ id: empty_post.id, cooked: empty_post.cooked }],
      )
    end
    source_post.update_columns(
      cooked: "<div class='ai-artifact' data-ai-artifact-id='#{artifact.id}'></div>",
    )
    SharedAiConversation.share_conversation(owner, topic)
    sign_in(owner)

    queries =
      track_sql_queries do
        get "#{base_path}.json", params: { type: "conversation", order: "oldest" }
      end
    expect(queries.size).to be <= 40
    first_page = response.parsed_body
    expect(first_page["items"]).to eq([])
    expect(first_page["has_more"]).to eq(true)
    expect(first_page["next_cursor"]["id"]).to eq(
      SharedAiConversation.where(user: owner).order(:created_at, :id).limit(100).last.id,
    )

    get "#{base_path}.json",
        params: {
          type: "conversation",
          order: "oldest",
          cursor: first_page["next_cursor"].to_json,
        }
    expect(response.parsed_body["items"].map { |card| card["name"] }).to eq([artifact.name])
    expect(response.parsed_body["has_more"]).to eq(false)
  end

  it "lists artifact cards from multiple posts in one conversation" do
    second_artifact = Fabricate(:ai_artifact, post: source_post, user: owner, name: "Second card")
    second_post = Fabricate(:post, topic: topic, user: owner)
    artifact.update!(post: second_post)
    source_post.update_columns(cooked: "<div data-ai-artifact-id='#{second_artifact.id}'></div>")
    second_post.update_columns(cooked: "<div data-ai-artifact-id='#{artifact.id}'></div>")
    SharedAiConversation.share_conversation(owner, topic)
    sign_in(owner)

    get "#{base_path}.json", params: { type: "conversation" }
    expect(response.parsed_body["items"].map { |card| card["name"] }).to contain_exactly(
      second_artifact.name,
      artifact.name,
    )
    expect(response.parsed_body["has_more"]).to eq(false)
  end

  it "lists one card per artifact when a conversation references multiple versions" do
    pinned = artifact.create_new_version(html: "<p>Pinned version</p>")
    source_post.update_columns(
      cooked:
        "<div class='ai-artifact' data-ai-artifact-id='#{artifact.id}'></div>" \
          "<div class='ai-artifact' data-artifact-id='#{artifact.id}' data-artifact-version='0'></div>" \
          "<div class='ai-artifact' data-ai-artifact-id='#{artifact.id}' data-ai-artifact-version='#{pinned.version_number}'></div>",
    )
    conversation = SharedAiConversation.share_conversation(owner, topic)
    sign_in(owner)

    get "#{base_path}.json", params: { type: "conversation" }
    expect(response.parsed_body["items"].map { |card| card["id"] }).to eq(
      ["conversation-#{conversation.id}-#{artifact.id}"],
    )
    card = response.parsed_body["items"].first
    expect(card["share_key"]).to eq(conversation.share_key)
    expect(card["url"]).to eq(conversation.url)
    expect(card["embed_url"]).to eq(AiArtifact.embed_url(artifact.id, pinned.version_number))
    expect(card.slice("artifact_id", "artifact_version")).to eq(
      "artifact_id" => artifact.id,
      "artifact_version" => pinned.version_number,
    )
    expect(response.parsed_body.to_json).not_to include("preview_url")

    sign_out
    get card["embed_url"]
    expect(response.status).to eq(200)
    expect(response.headers["X-Frame-Options"]).to be_nil
    expect(Nokogiri.HTML5(response.body).at_css("iframe")["srcdoc"]).to include(pinned.html)
  end

  it "hides expanded private conversations while retaining a previously published snapshot" do
    source_post.update_columns(cooked: "<div data-ai-artifact-id='#{artifact.id}'></div>")
    SharedAiConversation.share_conversation(owner, topic)
    sign_in(owner)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    key = response.parsed_body["share_key"]

    topic.topic_allowed_users.create!(user: Fabricate(:user))
    get "#{base_path}.json", params: { type: "conversation" }
    expect(response.parsed_body["items"]).to eq([])
    get "#{base_path}.json", params: { type: "standalone" }
    expect(response.parsed_body["items"].map { |item| item["share_key"] }).to eq([key])

    sign_out
    get "#{base_path}/#{key}"
    expect(response.status).to eq(200)
  end

  it "omits conversation cards when a context post is hidden, trashed, or belongs to another topic" do
    source_post.update_columns(cooked: "<div data-ai-artifact-id='#{artifact.id}'></div>")
    conversation = SharedAiConversation.share_conversation(owner, topic)
    sign_in(owner)

    get "#{base_path}.json", params: { type: "conversation" }
    expect(response.parsed_body["items"].map { |card| card["name"] }).to eq([artifact.name])

    source_post.update_columns(user_id: bot_user.id, hidden: true)
    get "#{base_path}.json", params: { type: "conversation" }
    expect(response.parsed_body["items"]).to eq([])

    source_post.update_columns(user_id: owner.id, hidden: false)
    source_post.trash!
    get "#{base_path}.json", params: { type: "conversation" }
    expect(response.parsed_body["items"]).to eq([])

    source_post.recover!
    other_topic = Fabricate(:private_message_topic, user: owner, recipient: bot_user)
    other_post = Fabricate(:post, topic: other_topic, user: owner)
    conversation.update_columns(context: [{ id: other_post.id, cooked: source_post.cooked }])
    get "#{base_path}.json", params: { type: "conversation" }
    expect(response.parsed_body["items"]).to eq([])
  end

  it "rejects a different requested version on create without changing the published snapshot" do
    version = artifact.create_new_version(html: "<p>Different version</p>")
    sign_in(owner)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    key = response.parsed_body["share_key"]

    post "#{base_path}/#{artifact.id}.json", params: { version: version.version_number }
    expect(response.status).to eq(409)
    expect(response.parsed_body["error"]).to eq(
      I18n.t("discourse_ai.ai_artifact.share_version_conflict"),
    )
    expect(AiArtifactShare.find_by!(share_key: key).version_number).to eq(0)
  end

  it "returns the existing link if another request creates it first" do
    existing = AiArtifactShare.new(ai_artifact: artifact, user: owner)
    existing.pin!(version_number: 0)
    expect(AiArtifactShare.where(ai_artifact: artifact, user: owner).count).to eq(1)
    sign_in(owner)

    AiArtifactShare.stubs(:find_by).returns(nil, existing)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    expect(response.status).to eq(200)
    expect(response.parsed_body["share_key"]).to eq(existing.share_key)
    expect(AiArtifactShare.where(ai_artifact: artifact, user: owner).count).to eq(1)
  end

  it "rejects restricted topics, multi-person PMs, and users outside the allowed groups" do
    sign_in(owner)
    group = Fabricate(:group)
    group.add(owner)
    restricted_category = Fabricate(:private_category, group: group)
    restricted_topic = Fabricate(:topic, user: owner, category: restricted_category)
    restricted_post = Fabricate(:post, topic: restricted_topic, user: owner)
    restricted_artifact = Fabricate(:ai_artifact, post: restricted_post, user: owner)
    expect(owner.guardian.can_see?(restricted_post)).to eq(true)
    post "#{base_path}/#{restricted_artifact.id}.json", params: { version: 0 }
    expect(response.status).to eq(404)

    SiteSetting.ai_bot_public_sharing_allowed_groups = "1"
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    expect(response.status).to eq(404)
    SiteSetting.ai_bot_public_sharing_allowed_groups = "10"

    topic.topic_allowed_users.create!(user: Fabricate(:user))
    get "#{base_path}/eligibility/#{artifact.id}.json"
    expect(response.parsed_body["can_share"]).to eq(false)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    expect(response.status).to eq(404)
  end

  it "refuses to repin an existing share when the owner's group or PM eligibility changes" do
    sign_in(owner)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    key = response.parsed_body["share_key"]
    version = artifact.create_new_version(html: "<p>Not published</p>")

    SiteSetting.ai_bot_public_sharing_allowed_groups = "1"
    put "#{base_path}/#{key}.json", params: { version: version.version_number }
    expect(response.status).to eq(404)

    SiteSetting.ai_bot_public_sharing_allowed_groups = "10"
    topic.topic_allowed_users.create!(user: Fabricate(:user))
    put "#{base_path}/#{key}.json", params: { version: version.version_number }
    expect(response.status).to eq(404)
    expect(AiArtifactShare.find_by!(share_key: key).version_number).to eq(0)
  end

  it "rejects an artifact owned by another human even when the PM creator can share the conversation" do
    artifact.update!(user: Fabricate(:user))
    sign_in(owner)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    expect(response.status).to eq(404)
  end

  it "rejects private upload references in any pinned version without changing the existing share" do
    sign_in(owner)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    key = response.parsed_body["share_key"]
    version = artifact.create_new_version(html: '<img src="/secure-uploads/private.png">')

    put "#{base_path}/#{key}.json", params: { version: version.version_number }
    expect(response.status).to eq(403)
    expect(response.parsed_body["errors"]).to include(
      I18n.t("discourse_ai.ai_artifact.uploads_cannot_be_shared"),
    )
    expect(AiArtifactShare.find_by!(share_key: key).version_number).to eq(0)

    artifact.update!(css: 'background: url("upload://private");')
    extra =
      Fabricate(
        :ai_artifact,
        post: source_post,
        user: owner,
        html: '<img src="/uploads/default/original/1X/secret.png">',
      )
    post "#{base_path}/#{extra.id}.json", params: { version: 0 }
    expect(response.status).to eq(403)
    expect(AiArtifactShare.where(ai_artifact: extra)).not_to exist
  end

  it "rejects HTML entity-encoded upload references in a snapshot" do
    artifact.update!(html: '<img src="&#47;secure-uploads&#47;private.png">')
    sign_in(owner)

    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    expect(response.status).to eq(403)
    expect(AiArtifactShare.where(ai_artifact: artifact)).not_to exist

    artifact.update!(html: "<p>Safe HTML</p>", css: "url(upload:&#47;&#47;private)")
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    expect(response.status).to eq(403)
    expect(AiArtifactShare.where(ai_artifact: artifact)).not_to exist
  end

  it "rejects legacy secure upload URLs in snapshots" do
    sign_in(owner)
    artifact.update!(html: '<img src="/secure-media-uploads/original/1X/private.png">')

    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }

    expect(response.status).to eq(403)
    expect(AiArtifactShare.where(ai_artifact: artifact)).not_to exist
  end

  it "rejects upload CDN URLs when the configured root ends in a slash" do
    SiteSetting.Upload.stubs(:enable_s3_uploads).returns(true)
    SiteSetting.Upload.stubs(:s3_base_url).returns("//uploads-bucket.s3.example.com/forum")
    SiteSetting.Upload.stubs(:s3_cdn_url).returns("https://uploads-cdn.example.com/forum/")
    sign_in(owner)
    artifact.update!(html: '<img src="//uploads-cdn.example.com/forum/original/private.png">')

    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }

    expect(response.status).to eq(403)
    expect(AiArtifactShare.where(ai_artifact: artifact)).not_to exist
  end

  it "rejects configured S3 and CDN upload roots in snapshots" do
    SiteSetting.Upload.stubs(:enable_s3_uploads).returns(true)
    SiteSetting.Upload.stubs(:s3_base_url).returns("//uploads-bucket.s3.example.com/forum")
    SiteSetting.Upload.stubs(:s3_cdn_url).returns("https://uploads-cdn.example.com/forum")
    sign_in(owner)

    artifact.update!(
      html: '<img src="https://uploads-bucket.s3.example.com/forum/original/private.png">',
    )
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    expect(response.status).to eq(403)
    expect(AiArtifactShare.where(ai_artifact: artifact)).not_to exist

    artifact.update!(
      html: "<p>Safe HTML</p>",
      js: 'fetch("//uploads-cdn.example.com/forum/original/private.png")',
    )
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    expect(response.status).to eq(403)
    expect(AiArtifactShare.where(ai_artifact: artifact)).not_to exist
  end

  it "stops serving a share if its source or owner is removed" do
    sign_in(owner)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    key = response.parsed_body["share_key"]
    source_post.trash!
    get "#{base_path}/#{key}"
    expect(response.status).to eq(404)
    source_post.recover!

    topic.trash!
    get "#{base_path}/#{key}"
    expect(response.status).to eq(404)
    topic.recover!

    share = AiArtifactShare.find_by!(share_key: key)
    share.update_columns(user_id: 2_000_000_000)
    get "#{base_path}/#{key}"
    expect(response.status).to eq(404)
    share.update_columns(user_id: owner.id)

    DiscourseEvent.trigger(:user_destroyed, owner)
    expect(AiArtifactShare.where(share_key: key)).not_to exist
    get "#{base_path}/#{key}"
    expect(response.status).to eq(404)
  end

  it "stops serving a published snapshot once sharing settings or group membership change" do
    sign_in(owner)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    key = response.parsed_body["share_key"]
    sign_out

    get "#{base_path}/#{key}"
    expect(response.status).to eq(200)

    SiteSetting.ai_bot_enabled = false
    get "#{base_path}/#{key}"
    expect(response.status).to eq(404)
    SiteSetting.ai_bot_enabled = true

    SiteSetting.ai_bot_public_sharing_allowed_groups = ""
    get "#{base_path}/#{key}"
    expect(response.status).to eq(404)
    SiteSetting.ai_bot_public_sharing_allowed_groups = "10"

    group = Fabricate(:group)
    SiteSetting.ai_bot_public_sharing_allowed_groups = group.id.to_s
    get "#{base_path}/#{key}"
    expect(response.status).to eq(404)

    group.add(owner)
    get "#{base_path}/#{key}"
    expect(response.status).to eq(200)

    group.remove(owner)
    get "#{base_path}/#{key}"
    expect(response.status).to eq(404)

    SiteSetting.ai_bot_public_sharing_allowed_groups = "10"
    get "#{base_path}/#{key}"
    expect(response.status).to eq(200)

    # Shutting the gate must not affect the artifact route users reach through the post
    sign_in(owner)
    get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"
    expect(response.status).to eq(200)
  end

  it "keeps unavailable snapshots listed for revocation without offering a working link" do
    sign_in(owner)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    key = response.parsed_body["share_key"]

    get "#{base_path}.json"
    expect(response.parsed_body["items"].first["available"]).to eq(true)

    source_post.trash!
    get "#{base_path}.json"
    expect(response.parsed_body["items"].first["available"]).to eq(false)

    source_post.recover!
    get "#{base_path}.json"
    expect(response.parsed_body["items"].first["available"]).to eq(true)

    SiteSetting.ai_bot_public_sharing_allowed_groups = "1"
    get "#{base_path}.json"
    expect(response.parsed_body["items"].first["available"]).to eq(false)
    expect(response.parsed_body["items"].first["share_key"]).to eq(key)

    delete "#{base_path}/#{key}.json"
    expect(response.status).to eq(204)
    get "#{base_path}.json"
    expect(response.parsed_body["items"]).to eq([])
  end

  it "lists an orphaned snapshot as unavailable until its owner revokes it" do
    sign_in(owner)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    key = response.parsed_body["share_key"]
    AiArtifact.where(id: artifact.id).delete_all

    get "#{base_path}.json", params: { type: "standalone" }
    expect(response.status).to eq(200)
    expect(
      response.parsed_body["items"].map { |item| [item["share_key"], item["available"]] },
    ).to eq([[key, false]])

    delete "#{base_path}/#{key}.json"
    expect(response.status).to eq(204)
    expect(AiArtifactShare.where(share_key: key)).not_to exist
  end

  it "merges shares and conversation events chronologically with type filters and stable card IDs" do
    second_artifact = Fabricate(:ai_artifact, post: source_post, user: owner, name: "Second")
    source_post.update_columns(
      cooked:
        "<div data-ai-artifact-id='#{artifact.id}'></div>" \
          "<div data-ai-artifact-id='#{second_artifact.id}'></div>",
    )
    conversation = SharedAiConversation.share_conversation(owner, topic)
    first_share = AiArtifactShare.new(ai_artifact: artifact, user: owner)
    first_share.pin!(version_number: 0)
    second_share = AiArtifactShare.new(ai_artifact: second_artifact, user: owner)
    second_share.pin!(version_number: 0)
    timestamp = Time.utc(2025, 1, 1, 12, 0, 0, 123_456)
    [conversation, first_share, second_share].each do |record|
      record.update_column(:created_at, timestamp)
    end
    sign_in(owner)

    ordered_events = [
      [conversation.id, "conversation"],
      [first_share.id, "standalone"],
      [second_share.id, "standalone"],
    ].sort
    card_ids =
      lambda do |events|
        events.flat_map do |id, type|
          if type == "conversation"
            ["conversation-#{id}-#{artifact.id}", "conversation-#{id}-#{second_artifact.id}"]
          else
            ["standalone-#{id}"]
          end
        end
      end
    get "#{base_path}.json"
    expect(response.parsed_body["items"].map { |item| item["id"] }).to eq(
      card_ids.call(ordered_events.reverse),
    )
    expect(response.parsed_body["has_more"]).to eq(false)
    get "#{base_path}.json", params: { order: "oldest" }
    expect(response.parsed_body["items"].map { |item| item["id"] }).to eq(
      card_ids.call(ordered_events),
    )
    expect(response.parsed_body["items"].map { |item| item["type"] }.tally).to eq(
      "standalone" => 2,
      "conversation" => 2,
    )
    get "#{base_path}.json", params: { type: "standalone" }
    expect(response.parsed_body["items"].map { |item| item["share_key"] }).to contain_exactly(
      first_share.share_key,
      second_share.share_key,
    )
    get "#{base_path}.json", params: { type: "conversation" }
    expect(response.parsed_body["items"].map { |item| item["id"] }).to eq(
      [
        "conversation-#{conversation.id}-#{artifact.id}",
        "conversation-#{conversation.id}-#{second_artifact.id}",
      ],
    )
  end

  it "continues across tied timestamps and deleted records without skipping a conversation event" do
    source_post.update_columns(cooked: "<div data-ai-artifact-id='#{artifact.id}'></div>")
    conversation = SharedAiConversation.share_conversation(owner, topic)
    shares =
      20.times.map do |index|
        extra = Fabricate(:ai_artifact, post: source_post, user: owner, name: "Extra #{index}")
        AiArtifactShare
          .new(ai_artifact: extra, user: owner)
          .tap { |share| share.pin!(version_number: 0) }
      end
    timestamp = Time.utc(2025, 1, 1, 12, 0, 0, 654_321)
    (shares + [conversation]).each { |record| record.update_column(:created_at, timestamp) }
    sign_in(owner)

    get "#{base_path}.json"
    first_page = response.parsed_body
    expect(first_page["items"].length).to eq(20)
    expect(first_page["has_more"]).to eq(true)
    seen_ids = first_page["items"].map { |item| item["id"] }
    share_to_delete = shares.find { |share| seen_ids.include?("standalone-#{share.id}") }
    share_to_delete.destroy!

    get "#{base_path}.json", params: { cursor: first_page["next_cursor"].to_json }
    remaining_ids = response.parsed_body["items"].map { |item| item["id"] }
    expect((seen_ids + remaining_ids).sort).to eq(
      (
        shares.map { |share| "standalone-#{share.id}" } +
          ["conversation-#{conversation.id}-#{artifact.id}"]
      ).sort,
    )
    expect(response.parsed_body["has_more"]).to eq(false)
  end

  it "rejects invalid feed filters, orders, and cursors" do
    sign_in(owner)
    ["bad", "", "conversations"].each do |type|
      get "#{base_path}.json", params: { type: type }
      expect(response.status).to eq(400)
    end
    get "#{base_path}.json", params: { order: "random" }
    expect(response.status).to eq(400)
    [
      "oops",
      "[]",
      "{}",
      { id: 2 },
      { created_at: "yesterday", id: 1, type: "standalone", order: "newest", filter: "all" },
    ].each do |cursor|
      get "#{base_path}.json",
          params: {
            cursor: cursor.is_a?(Hash) && cursor.key?(:created_at) ? cursor.to_json : cursor,
          }
      expect(response.status).to eq(400)
    end
    AiArtifactShare.new(ai_artifact: artifact, user: owner).pin!(version_number: 0)
    get "#{base_path}.json"
    cursor =
      response.parsed_body["next_cursor"] ||
        {
          created_at: AiArtifactShare.last.created_at.utc.iso8601(6),
          id: AiArtifactShare.last.id,
          type: "standalone",
          order: "newest",
          filter: "all",
        }
    get "#{base_path}.json", params: { type: "conversation", cursor: cursor.to_json }
    expect(response.status).to eq(400)
    get "#{base_path}.json", params: { order: "oldest", cursor: cursor.to_json }
    expect(response.status).to eq(400)
  end

  it "does not split a conversation with more than twenty artifact cards" do
    artifacts = [artifact]
    20.times do |index|
      artifacts << Fabricate(:ai_artifact, post: source_post, user: owner, name: "Card #{index}")
    end
    source_post.update_columns(
      cooked: artifacts.map { |item| "<div data-ai-artifact-id='#{item.id}'></div>" }.join,
    )
    SharedAiConversation.share_conversation(owner, topic)
    sign_in(owner)

    get "#{base_path}.json", params: { type: "conversation" }
    expect(response.parsed_body["items"].map { |item| item["name"] }).to eq(artifacts.map(&:name))
    expect(response.parsed_body["has_more"]).to eq(false)
  end

  it "limits updates as well as creates" do
    RateLimiter.enable
    sign_in(owner)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    key = response.parsed_body["share_key"]
    9.times { put "#{base_path}/#{key}.json", params: { version: 0 } }
    expect(response.status).to eq(200)
    put "#{base_path}/#{key}.json", params: { version: 0 }
    expect(response.status).to eq(429)
  ensure
    RateLimiter.disable
  end

  it "requires login for listing and refuses a guest attempting mutation" do
    get "#{base_path}.json"
    expect(response.status).not_to eq(200)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    expect(response.status).not_to eq(201)
  end

  it "runs the pinned forum snapshot with viewer identity and share-only storage" do
    sign_in(owner)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    key = response.parsed_body["share_key"]
    pinned_html = artifact.html
    artifact.update!(html: "<p>Future private version</p>")
    original =
      Fabricate(
        :ai_artifact_key_value,
        ai_artifact: artifact,
        user: owner,
        key: "source",
        value: "secret",
        public: true,
      )

    get "#{base_path}/#{key}/forum"
    expect(response.status).to eq(200)
    expect(response.headers["X-Frame-Options"]).to eq("SAMEORIGIN")
    expect(response.headers["Content-Security-Policy"]).to include("frame-ancestors 'self'")
    expect(response.headers["Cache-Control"]).to eq("no-store")
    frame = Nokogiri.HTML5(response.body).at_css("iframe")
    expect(frame["sandbox"]).to eq("allow-scripts allow-forms")
    expect(frame["srcdoc"]).to include(pinned_html, "\"user_id\":#{owner.id}")
    expect(frame["srcdoc"]).not_to include(artifact.html, original.value)
    expect(response.body).to include("artifact-share-key-values/#{key}.json", "csrf-token")
    expect(response.body).not_to include("artifact-key-values/#{artifact.id}.json")

    get "#{base_path}/#{key}"
    expect(response.body).not_to include(
      "csrf-token",
      "discourse-artifact-kv",
      "_discourse_user_data",
    )
  end

  it "runs native shares for guests without exposing identity or accepting writes" do
    share = AiArtifactShare.new(ai_artifact: artifact, user: owner)
    share.pin!(version_number: 0)
    storage = "/discourse-ai/ai-bot/artifact-share-key-values/#{share.share_key}.json"

    get "#{base_path}/#{share.share_key}/forum"
    expect(response.status).to eq(200)
    expect(Nokogiri.HTML5(response.body).at_css("iframe")["srcdoc"]).to include("\"user_id\":null")
    get storage, params: { all_users: true }
    expect(response.status).to eq(200)
    post storage, params: { key: "guest", value: "no" }
    expect(response.status).not_to eq(200)
  end

  it "isolates share keys and users, permits only public cross-user reads and own writes" do
    sign_in(owner)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    key = response.parsed_body["share_key"]
    storage = "/discourse-ai/ai-bot/artifact-share-key-values/#{key}.json"
    original =
      Fabricate(
        :ai_artifact_key_value,
        ai_artifact: artifact,
        user: owner,
        key: "source",
        value: "secret",
        public: true,
      )
    post storage, params: { key: "vote", value: "owner vote", public: true }
    expect(response.status).to eq(200)
    expect(original.reload.value).to eq("secret")

    other_user = Fabricate(:user)
    sign_in(other_user)
    get storage, params: { all_users: true }
    expect(response.parsed_body["key_values"].map { |item| item["key"] }).to eq(["vote"])
    expect(response.body).not_to include(original.value)
    post storage, params: { key: "vote", value: "other vote", public: false }
    expect(response.status).to eq(200)
    get storage
    expect(response.parsed_body["key_values"].map { |item| item["value"] }).to eq(["other vote"])
    delete storage, params: { key: "vote" }
    expect(response.status).to eq(200)
    get storage, params: { all_users: true }
    expect(response.parsed_body["key_values"].map { |item| item["value"] }).to eq(["owner vote"])
  end

  it "checks settings, owner eligibility, source trash, and revocation for the forum runtime and storage" do
    sign_in(owner)
    post "#{base_path}/#{artifact.id}.json", params: { version: 0 }
    key = response.parsed_body["share_key"]
    forum = "#{base_path}/#{key}/forum"
    storage = "/discourse-ai/ai-bot/artifact-share-key-values/#{key}.json"
    post storage, params: { key: "vote", value: "stored" }
    expect(response.status).to eq(200)

    SiteSetting.ai_bot_public_sharing_allowed_groups = "1"
    get forum
    expect(response.status).to eq(404)
    get storage
    expect(response.status).to eq(404)
    post storage, params: { key: "vote", value: "changed" }
    expect(response.status).to eq(404)
    SiteSetting.ai_bot_public_sharing_allowed_groups = "10"
    source_post.trash!
    get forum
    expect(response.status).to eq(404)
    get storage
    expect(response.status).to eq(404)
    source_post.recover!
    topic.trash!
    get forum
    expect(response.status).to eq(404)
    get storage
    expect(response.status).to eq(404)
    topic.recover!
    SiteSetting.ai_bot_enabled = false
    get forum
    expect(response.status).to eq(404)
    get storage
    expect(response.status).to eq(404)
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_artifact_security = "disabled"
    get forum
    expect(response.status).to eq(404)
    get storage
    expect(response.status).to eq(404)
    SiteSetting.ai_artifact_security = "strict"
    delete "#{base_path}/#{key}.json"
    expect(response.status).to eq(204)
    get forum
    expect(response.status).to eq(404)
    get storage
    expect(response.status).to eq(404)
  end

  it "keeps other shares private even for admins and never borrows source keys" do
    first_share = AiArtifactShare.new(ai_artifact: artifact, user: owner)
    first_share.pin!(version_number: 0)
    second_artifact = Fabricate(:ai_artifact, post: source_post, user: owner)
    second_share = AiArtifactShare.new(ai_artifact: second_artifact, user: owner)
    second_share.pin!(version_number: 0)
    first_share.key_values.create!(user: owner, key: "poll", value: "private vote")
    second_share.key_values.create!(user: owner, key: "poll", value: "other poll", public: true)
    Fabricate(
      :ai_artifact_key_value,
      ai_artifact: artifact,
      user: owner,
      key: "poll",
      value: "source vote",
      public: true,
    )
    sign_in(Fabricate(:admin))

    get "/discourse-ai/ai-bot/artifact-share-key-values/#{first_share.share_key}.json",
        params: {
          all_users: true,
        }
    expect(response.status).to eq(200)
    expect(response.parsed_body["key_values"]).to eq([])
    get "/discourse-ai/ai-bot/artifact-share-key-values/#{second_share.share_key}.json",
        params: {
          all_users: true,
        }
    expect(response.parsed_body["key_values"].map { |item| item["value"] }).to eq(["other poll"])
  end

  it "preserves the global login wall for native embeds and share storage" do
    share = AiArtifactShare.new(ai_artifact: artifact, user: owner)
    share.pin!(version_number: 0)
    SiteSetting.login_required = true

    get "#{base_path}/#{share.share_key}/forum"
    expect(response).to redirect_to("/login")
    get "/discourse-ai/ai-bot/artifact-share-key-values/#{share.share_key}.json"
    expect(response.status).to eq(403)
  end

  it "applies artifact storage key and value limits independently to each share" do
    share = AiArtifactShare.new(ai_artifact: artifact, user: owner)
    share.pin!(version_number: 0)
    SiteSetting.ai_artifact_max_keys_per_user_per_artifact = 1
    SiteSetting.ai_artifact_kv_value_max_length = 5
    sign_in(owner)
    storage = "/discourse-ai/ai-bot/artifact-share-key-values/#{share.share_key}.json"

    post storage, params: { key: "one", value: "ok" }
    expect(response.status).to eq(200)
    post storage, params: { key: "two", value: "ok" }
    expect(response.status).to eq(422)
    post storage, params: { key: "one", value: "too long" }
    expect(response.status).to eq(422)
    get storage
    expect(response.parsed_body["key_values"].map { |item| item["value"] }).to eq(["ok"])
  end
end
