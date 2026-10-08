# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::SharedAiConversationsController do
  before do
    enable_current_plugin
    toggle_enabled_bots(bots: [claude_2])
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_allowed_groups = "10"
    SiteSetting.ai_bot_public_sharing_allowed_groups = "10"
  end

  fab!(:claude_2) { Fabricate(:llm_model, name: "claude-2") }
  fab!(:agent) { Fabricate(:ai_agent, default_llm: claude_2).tap(&:ensure_user!) }

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:attacker) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic)
  fab!(:pm, :private_message_topic)
  fab!(:user_pm) { Fabricate(:private_message_topic, recipient: user) }

  fab!(:bot_user) { agent.user }

  fab!(:user_pm_share) do
    pm_topic = Fabricate(:private_message_topic, user: user, recipient: bot_user)
    # a different unknown user
    Fabricate(:post, topic: pm_topic, user: user)
    Fabricate(
      :post,
      topic: pm_topic,
      user: bot_user,
      custom_fields: {
        DiscourseAi::AiBot::POST_AI_AGENT_ID_FIELD => agent.id,
        DiscourseAi::AiBot::POST_AI_LLM_MODEL_ID_FIELD => claude_2.id,
        DiscourseAi::AiBot::POST_AI_LLM_NAME_FIELD => "Claude-2",
      },
    )
    Fabricate(:post, topic: pm_topic, user: user)
    pm_topic
  end

  let(:path) { "/discourse-ai/ai-bot/shared-ai-conversations" }
  let(:shared_conversation) { SharedAiConversation.share_conversation(user, user_pm_share) }

  def share_error(key)
    I18n.t("discourse_ai.share_ai.errors.#{key}")
  end

  describe "GET index" do
    it "lists only the owner's conversations without requiring artifact cards or exposing context" do
      sign_in(user)
      conversation = shared_conversation
      other_conversation =
        SharedAiConversation.share_conversation(
          attacker,
          Fabricate(:private_message_topic, user: attacker, recipient: bot_user),
        )
      conversation.update_columns(
        excerpt: "Private excerpt",
        context: [{ id: user_pm_share.posts.first.id, cooked: "Private context" }],
      )

      get "#{path}.json"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "items" => [
          {
            "id" => conversation.id,
            "share_key" => conversation.share_key,
            "title" => conversation.title,
            "url" => conversation.url,
            "created_at" => conversation.created_at.as_json,
            "available" => true,
          },
        ],
        "has_more" => false,
        "next_cursor" => nil,
      )
      expect(response.body).not_to include(
        conversation.excerpt,
        conversation.context.first["cooked"],
        other_conversation.share_key,
      )
    end

    it "returns unavailable snapshots for deleted posts, deleted topics, and revoked sharing groups" do
      sign_in(user)
      conversation = shared_conversation
      post = user_pm_share.posts.first
      post.trash!
      get "#{path}.json"
      expect(response.parsed_body["items"].sole["available"]).to eq(false)

      post.recover!
      user_pm_share.trash!
      get "#{path}.json"
      expect(response.parsed_body["items"].sole["available"]).to eq(false)

      user_pm_share.recover!
      SiteSetting.ai_bot_enabled = false
      get "#{path}.json"
      expect(response.parsed_body["items"].sole["available"]).to eq(false)

      SiteSetting.ai_bot_enabled = true
      SiteSetting.ai_bot_public_sharing_allowed_groups = ""
      get "#{path}.json"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["items"].sole["available"]).to eq(false)
      delete "#{path}/#{conversation.share_key}.json"
      expect(response).to have_http_status(:ok)
      expect(SharedAiConversation.exists?(conversation.id)).to eq(false)
    end

    it "retains a snapshot when its source topic or context post no longer exists" do
      sign_in(user)
      conversation = shared_conversation
      Post.where(id: conversation.context.first["id"]).delete_all
      get "#{path}.json"
      expect(response.parsed_body["items"].sole.slice("id", "available")).to eq(
        "id" => conversation.id,
        "available" => false,
      )

      Topic.where(id: conversation.target_id).delete_all
      get "#{path}.json"
      expect(response.parsed_body["items"].sole.slice("id", "available")).to eq(
        "id" => conversation.id,
        "available" => false,
      )
      delete "#{path}/#{conversation.share_key}.json"
      expect(response).to have_http_status(:ok)
    end

    it "does not mark context posts from another topic available" do
      sign_in(user)
      conversation = shared_conversation
      other_post = Fabricate(:post, topic: user_pm, user: user)
      conversation.update_columns(context: [{ id: other_post.id, cooked: other_post.cooked }])

      get "#{path}.json"

      expect(response.parsed_body["items"].sole["available"]).to eq(false)
    end

    it "paginates 20 rows in both directions without skipping tied timestamps or deleted rows" do
      sign_in(user)
      conversations =
        22.times.map do |index|
          pm_topic = Fabricate(:private_message_topic, user: user, recipient: bot_user)
          post = Fabricate(:post, topic: pm_topic, user: user)
          SharedAiConversation.create!(
            user: user,
            target: pm_topic,
            title: "Conversation #{index}",
            llm_name: "Bot",
            excerpt: "Snapshot",
            context: [{ id: post.id, cooked: post.cooked }],
          )
        end
      timestamp = Time.utc(2026, 1, 1, 12, 0, 0, 123_456)
      SharedAiConversation.where(id: conversations.map(&:id)).update_all(created_at: timestamp)

      %w[newest oldest].each do |order|
        get "#{path}.json", params: { order: order }
        first_page = response.parsed_body
        expect(first_page["items"].size).to eq(20)
        expect(first_page["has_more"]).to eq(true)
        expect(first_page["next_cursor"].keys.sort).to eq(%w[created_at id order])
        expected_ids = first_page["items"].map { |item| item["id"] }
        remaining_ids =
          SharedAiConversation.where(user: user).where.not(id: expected_ids).pluck(:id)
        SharedAiConversation.find(expected_ids.last).destroy!
        get "#{path}.json", params: { order: order, cursor: first_page["next_cursor"].to_json }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["items"].map { |item| item["id"] }).to eq(
          order == "newest" ? remaining_ids.sort.reverse : remaining_ids.sort,
        )
        expect(response.parsed_body["has_more"]).to eq(false)
        expect(response.parsed_body["next_cursor"]).to be_nil
      end
    end

    it "rejects malformed, oversized, and order-mismatched cursors and invalid orders" do
      sign_in(user)
      get "#{path}.json", params: { order: "reverse" }
      expect(response).not_to have_http_status(:success)

      [
        "no json",
        "x" * 513,
        { order: "oldest", created_at: Time.now.utc.iso8601(6), id: 1 }.to_json,
        { order: "newest", created_at: "tomorrow", id: 1 }.to_json,
        { order: "newest", created_at: Time.now.utc.iso8601(6), id: 0 }.to_json,
      ].each do |cursor|
        get "#{path}.json", params: { cursor: cursor }
        expect(response).not_to have_http_status(:success)
      end
    end

    it "bounds queries when listing many conversations" do
      sign_in(user)
      21.times do
        pm_topic = Fabricate(:private_message_topic, user: user, recipient: bot_user)
        post = Fabricate(:post, topic: pm_topic, user: user)
        SharedAiConversation.create!(
          user: user,
          target: pm_topic,
          title: pm_topic.title,
          llm_name: "Bot",
          excerpt: "Snapshot",
          context: [{ id: post.id, cooked: post.cooked }],
        )
      end

      queries = track_sql_queries { get "#{path}.json" }
      expect(response.parsed_body["items"].size).to eq(20)
      expect(queries.size).to be <= 230
    end

    it "does not list another owner's snapshots, even for an admin" do
      shared_conversation
      sign_in(attacker)
      get "#{path}.json"
      expect(response.parsed_body["items"]).to eq([])

      sign_in(Fabricate(:admin))
      get "#{path}.json"
      expect(response.parsed_body["items"]).to eq([])
    end

    it "requires login" do
      conversation = shared_conversation
      get "#{path}.json"
      expect(response).not_to have_http_status(:success)
      expect(response.body).not_to include(conversation.share_key)
    end

    it "requires the AI plugin setting for listing and revoking" do
      sign_in(user)
      conversation = shared_conversation
      SiteSetting.discourse_ai_enabled = false
      get "#{path}.json"
      expect(response).to have_http_status(:not_found)
      delete "#{path}/#{conversation.share_key}.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST create" do
    context "when logged in" do
      before { sign_in(user) }

      it "denies creating a new shared conversation on public topics" do
        post "#{path}.json", params: { topic_id: topic.id }
        expect(response).not_to have_http_status(:success)

        expect(response.parsed_body["errors"]).to eq([share_error(:not_allowed)])
        expect(response.parsed_body["errors"].to_s).not_to include("Translation missing")
      end

      it "denies creating a new shared conversation for a random PM" do
        post "#{path}.json", params: { topic_id: pm.id }
        expect(response).not_to have_http_status(:success)

        expect(response.parsed_body["errors"]).to eq([share_error(:not_allowed)])
        expect(response.parsed_body["errors"].to_s).not_to include("Translation missing")
      end

      it "denies creating a shared conversation for my PMs not with bots" do
        post "#{path}.json", params: { topic_id: user_pm.id }
        expect(response).not_to have_http_status(:success)
        expect(response.parsed_body["errors"]).to eq([share_error(:other_people_in_pm)])
        expect(response.parsed_body["errors"].to_s).not_to include("Translation missing")
      end

      it "denies creating a shared conversation for my PMs with bots that also have other users" do
        pm_topic = Fabricate(:private_message_topic, user: user, recipient: bot_user)
        # a different unknown user
        Fabricate(:post, topic: pm_topic)
        post "#{path}.json", params: { topic_id: pm_topic.id }
        expect(response).not_to have_http_status(:success)

        expect(response.parsed_body["errors"]).to eq([share_error(:other_content_in_pm)])
        expect(response.parsed_body["errors"].to_s).not_to include("Translation missing")
      end

      it "allows creating a shared conversation for my PMs with bots only" do
        post "#{path}.json", params: { topic_id: user_pm_share.id }
        expect(response).to have_http_status(:success)
      end

      context "when ai artifacts are in lax mode" do
        before { SiteSetting.ai_artifact_security = "lax" }

        it "properly shares artifacts" do
          first_post = user_pm_share.posts.first

          artifact_not_allowed =
            AiArtifact.create!(
              user: bot_user,
              post: Fabricate(:private_message_post),
              name: "test",
              html: "<div>test</div>",
            )

          artifact =
            AiArtifact.create!(
              user: bot_user,
              post: first_post,
              name: "test",
              html: "<div>test</div>",
            )

          # lets log out and see we can not access the artifacts
          delete "/session/#{user.id}"

          get artifact.url
          expect(response).to have_http_status(:not_found)

          get artifact_not_allowed.url
          expect(response).to have_http_status(:not_found)

          sign_in(user)

          first_post.update!(raw: <<~RAW)
            This is a post with an artifact

            <div class="ai-artifact" data-ai-artifact-id="#{artifact.id}"></div>
            <div class="ai-artifact" data-ai-artifact-id="#{artifact_not_allowed.id}"></div>
          RAW

          post "#{path}.json", params: { topic_id: user_pm_share.id }
          expect(response).to have_http_status(:success)

          key = response.parsed_body["share_key"]

          get "#{path}/#{key}"
          expect(response).to have_http_status(:success)

          expect(response.body).to include(artifact.url)
          expect(response.body).to include(artifact_not_allowed.url)

          # lets log out and see we can not access the artifacts
          delete "/session/#{user.id}"

          get artifact.url
          expect(response).to have_http_status(:success)

          get artifact_not_allowed.url
          expect(response).to have_http_status(:not_found)

          sign_in(user)
          delete "#{path}/#{key}.json"
          expect(response).to have_http_status(:success)

          # we can not longer see it...
          delete "/session/#{user.id}"
          get artifact.url
          expect(response).to have_http_status(:not_found)
        end
      end

      context "when secure uploads are enabled" do
        let(:upload_1) { Fabricate(:s3_image_upload, user: bot_user, secure: true) }
        let(:upload_2) { Fabricate(:s3_image_upload, user: bot_user, secure: true) }
        let(:post_with_upload_1) { Fabricate(:post, topic: user_pm_share, user: bot_user) }
        let(:post_with_upload_2) { Fabricate(:post, topic: user_pm_share, user: bot_user) }

        before do
          enable_secure_uploads
          stub_s3_store
          SiteSetting.secure_uploads_pm_only = true
          FileStore::S3Store.any_instance.stubs(:update_upload_ACL).returns(true)
          Jobs.run_immediately!

          upload_1.update!(
            access_control_post: post_with_upload_1,
            sha1: SecureRandom.hex(20),
            original_sha1: upload_1.sha1,
          )
          upload_2.update!(
            access_control_post: post_with_upload_2,
            sha1: SecureRandom.hex(20),
            original_sha1: upload_2.sha1,
          )
          PostRevisor.new(post_with_upload_1).revise!(
            Discourse.system_user,
            raw: "This is a post with a cool AI generated picture ![wow](#{upload_1.short_url})",
          )
          PostRevisor.new(post_with_upload_2).revise!(
            Discourse.system_user,
            raw:
              "Another post that has been birthed by AI with a picture ![meow](#{upload_2.short_url})",
          )
        end

        it "marks all of those uploads as not secure when sharing the topic" do
          post "#{path}.json", params: { topic_id: user_pm_share.id }
          expect(response).to have_http_status(:success)
          expect(upload_1.reload.secure).to eq(false)
          expect(upload_2.reload.secure).to eq(false)
        end

        it "rebakes any posts in the topic with uploads attached when sharing the topic so image urls become non-secure" do
          post_1_cooked = post_with_upload_1.cooked
          post_2_cooked = post_with_upload_2.cooked

          post "#{path}.json", params: { topic_id: user_pm_share.id }
          expect(response).to have_http_status(:success)

          expect(post_with_upload_1.reload.cooked).not_to eq(post_1_cooked)
          expect(post_with_upload_1.reload.cooked).not_to include("secure-uploads")
          expect(post_with_upload_2.reload.cooked).not_to eq(post_2_cooked)
          expect(post_with_upload_2.reload.cooked).not_to include("secure-uploads")
        end
      end
    end

    context "when not logged in" do
      it "requires login" do
        post "#{path}.json", params: { topic_id: topic.id }
        expect(response).not_to have_http_status(:success)
      end
    end
  end

  describe "DELETE destroy" do
    context "when logged in" do
      before { sign_in(user) }

      it "deletes the shared conversation" do
        delete "#{path}/#{shared_conversation.share_key}.json"
        expect(response).to have_http_status(:success)
        expect(SharedAiConversation.exists?(shared_conversation.id)).to be_falsey
      end

      it "returns an error if the shared conversation is not found" do
        delete "#{path}/123.json"
        expect(response).not_to have_http_status(:success)
      end

      context "when secure uploads are enabled" do
        let(:upload_1) { Fabricate(:s3_image_upload, user: bot_user, secure: false) }
        let(:upload_2) { Fabricate(:s3_image_upload, user: bot_user, secure: false) }

        before do
          enable_secure_uploads
          stub_s3_store
          SiteSetting.secure_uploads_pm_only = true
          FileStore::S3Store.any_instance.stubs(:update_upload_ACL).returns(true)
          Jobs.run_immediately!

          upload_1.update!(
            access_control_post: shared_conversation.target.posts.first,
            sha1: SecureRandom.hex(20),
            original_sha1: upload_1.sha1,
          )
          upload_2.update!(
            access_control_post: shared_conversation.target.posts.second,
            sha1: SecureRandom.hex(20),
            original_sha1: upload_2.sha1,
          )
          PostRevisor.new(shared_conversation.target.posts.first).revise!(
            Discourse.system_user,
            raw: "This is a post with a cool AI generated picture ![wow](#{upload_1.short_url})",
          )
          PostRevisor.new(shared_conversation.target.posts.second).revise!(
            Discourse.system_user,
            raw:
              "Another post that has been birthed by AI with a picture ![meow](#{upload_2.short_url})",
          )
        end

        it "marks all uploads in the PM back as secure when unsharing the conversation" do
          delete "#{path}/#{shared_conversation.share_key}.json"
          expect(response).to have_http_status(:success)
          expect(upload_1.reload.secure).to eq(true)
          expect(upload_2.reload.secure).to eq(true)
        end

        it "rebakes any posts in the topic with uploads attached when sharing the topic so image urls become secure" do
          post_1_cooked = shared_conversation.target.posts.first.cooked
          post_2_cooked = shared_conversation.target.posts.second.cooked

          delete "#{path}/#{shared_conversation.share_key}.json"
          expect(response).to have_http_status(:success)

          expect(shared_conversation.target.posts.first.reload.cooked).not_to eq(post_1_cooked)
          expect(shared_conversation.target.posts.first.reload.cooked).to include("secure-uploads")
          expect(shared_conversation.target.posts.second.reload.cooked).not_to eq(post_2_cooked)
          expect(shared_conversation.target.posts.second.reload.cooked).to include("secure-uploads")
        end

        it "marks uploads back as secure when unsharing after the source topic was trashed" do
          shared_conversation.target.trash!

          delete "#{path}/#{shared_conversation.share_key}.json"
          expect(response).to have_http_status(:success)
          expect(upload_1.reload.secure).to eq(true)
          expect(upload_2.reload.secure).to eq(true)
        end
      end

      context "when ai artifacts are in lax mode" do
        before { SiteSetting.ai_artifact_security = "lax" }

        it "marks artifacts private when unsharing after the source topic was trashed" do
          first_post = user_pm_share.posts.first
          artifact =
            AiArtifact.create!(
              user: bot_user,
              post: first_post,
              name: "test",
              html: "<div>test</div>",
            )

          first_post.update!(raw: <<~RAW)
              This is a post with an artifact

              <div class="ai-artifact" data-ai-artifact-id="#{artifact.id}"></div>
            RAW

          conversation = SharedAiConversation.share_conversation(user, user_pm_share)
          expect(artifact.reload.public?).to eq(true)

          user_pm_share.trash!

          delete "#{path}/#{conversation.share_key}.json"
          expect(response).to have_http_status(:success)
          expect(artifact.reload.public?).to eq(false)
        end
      end
    end

    context "when not logged in" do
      it "requires login" do
        delete "#{path}/#{shared_conversation.share_key}.json"
        expect(response).not_to have_http_status(:success)
      end
    end
  end

  describe "GET asset" do
    let(:helper) { Class.new { extend DiscourseAi::AiBot::SharedAiConversationsHelper } }

    it "renders highlight js correctly" do
      get helper.share_asset_url("highlight.js")

      expect(response).to be_successful
      expect(response.headers["Content-Type"]).to eq("application/javascript; charset=utf-8")

      js = File.read(DiscourseAi.public_asset_path("ai-share/highlight.min.js"))
      expect(response.body).to eq(js)
    end

    it "renders css correctly" do
      get helper.share_asset_url("share.css")

      expect(response).to be_successful
      expect(response.headers["Content-Type"]).to eq("text/css; charset=utf-8")

      css = File.read(DiscourseAi.public_asset_path("ai-share/share.css"))
      expect(response.body).to eq(css)
    end
  end

  describe "GET preview" do
    it "denies preview from logged out users" do
      get "#{path}/preview/#{user_pm_share.id}.json"
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["error_type"]).to eq("not_logged_in")
    end

    context "when logged in" do
      before { sign_in(user) }

      it "renders the shared conversation" do
        get "#{path}/preview/#{user_pm_share.id}.json"
        expect(response).to have_http_status(:success)
        expect(response.parsed_body["llm_name"]).to eq("Claude-2")
        expect(response.parsed_body["error"]).to eq(nil)
        expect(response.parsed_body["share_key"]).to eq(nil)
        expect(response.parsed_body["context"].length).to eq(3)

        shared_conversation
        get "#{path}/preview/#{user_pm_share.id}.json"

        expect(response).to have_http_status(:success)
        expect(response.parsed_body["share_key"]).to eq(shared_conversation.share_key)

        SiteSetting.ai_bot_public_sharing_allowed_groups = ""
        get "#{path}/preview/#{user_pm_share.id}.json"
        expect(response).not_to have_http_status(:success)
      end

      it "denies preview when there are other people in the PM" do
        other_user = Fabricate(:user)
        pm_topic = Fabricate(:private_message_topic, user: user, recipient: bot_user)
        pm_topic.topic_allowed_users.create!(user_id: other_user.id)
        Fabricate(:post, topic: pm_topic, user: user)
        Fabricate(:post, topic: pm_topic, user: bot_user)

        get "#{path}/preview/#{pm_topic.id}.json"
        expect(response).not_to have_http_status(:success)
      end

      it "denies preview when there is other content in the PM" do
        pm_topic = Fabricate(:private_message_topic, user: user, recipient: bot_user)
        Fabricate(:post, topic: pm_topic, user: user)
        Fabricate(:post, topic: pm_topic)

        get "#{path}/preview/#{pm_topic.id}.json"
        expect(response).not_to have_http_status(:success)
      end

      it "does not share artifacts publicly when previewing a valid conversation" do
        SiteSetting.ai_artifact_security = "lax"
        first_post = user_pm_share.posts.first

        artifact =
          AiArtifact.create!(
            user: bot_user,
            post: first_post,
            name: "test",
            html: "<div>test</div>",
          )

        cooked_html =
          "<p>Post with artifact</p>\n<div class=\"ai-artifact\" data-ai-artifact-id=\"#{artifact.id}\"></div>"
        first_post.update_columns(
          raw:
            "Post with artifact\n<div class=\"ai-artifact\" data-ai-artifact-id=\"#{artifact.id}\"></div>",
          cooked: cooked_html,
        )

        get "#{path}/preview/#{user_pm_share.id}.json"
        expect(response).to have_http_status(:success)

        artifact.reload
        expect(artifact.metadata&.dig("public")).not_to eq(true)
      end
    end
  end

  describe "GET /onebox" do
    it "does not expose a trashed conversation through a local onebox preview" do
      source_post = user_pm_share.posts.last
      source_post.update!(raw: "private transcript excerpt")
      conversation = SharedAiConversation.share_conversation(user, user_pm_share)
      user_pm_share.trash!

      sign_in(attacker)
      get "/onebox.json", params: { url: conversation.url }

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include(source_post.raw)
    end
  end

  describe "GET show" do
    it "redirects to home page if site require login" do
      SiteSetting.login_required = true
      get "#{path}/#{shared_conversation.share_key}"
      expect(response).to redirect_to("/login")
    end

    it "renders the shared conversation" do
      get "#{path}/#{shared_conversation.share_key}"
      expect(response).to have_http_status(:success)
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
      expect(response.body).not_to include("Translation missing")
      expect(response.headers["Cache-Control"]).to eq("max-age=60, public")
    end

    it "is also able to render in json format" do
      get "#{path}/#{shared_conversation.share_key}.json"
      expect(response.parsed_body["llm_name"]).to eq("Claude-2")
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
    end

    it "returns not found when the source topic has been trashed" do
      share_key = shared_conversation.share_key
      user_pm_share.trash!

      get "#{path}/#{share_key}.json"
      expect(response).to have_http_status(:not_found)
    end

    it "returns not found when a shared source post has been trashed" do
      share_key = shared_conversation.share_key
      user_pm_share.posts.last.trash!

      get "#{path}/#{share_key}.json"
      expect(response).to have_http_status(:not_found)
    end

    it "returns an error if the shared conversation is not found" do
      get "#{path}/123"
      expect(response).to have_http_status(:not_found)
    end
  end
end
