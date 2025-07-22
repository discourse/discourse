# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::AiBot::SharedAiConversationsController do
  before do
    enable_current_plugin
    toggle_enabled_bots(bots: [claude_2])
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_allowed_groups = "10"
    SiteSetting.ai_bot_public_sharing_allowed_groups = "10"
  end

  fab!(:claude_2) { Fabricate(:llm_model, name: "claude-2") }

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic)
  fab!(:pm) { Fabricate(:private_message_topic) }
  fab!(:user_pm) { Fabricate(:private_message_topic, recipient: user) }

  fab!(:bot_user) do
    enable_current_plugin
    toggle_enabled_bots(bots: [claude_2])
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_allowed_groups = "10"
    SiteSetting.ai_bot_public_sharing_allowed_groups = "10"
    claude_2.reload.user
  end

  fab!(:user_pm_share) do
    pm_topic = Fabricate(:private_message_topic, user: user, recipient: bot_user)
    # a different unknown user
    Fabricate(:post, topic: pm_topic, user: user)
    Fabricate(:post, topic: pm_topic, user: bot_user)
    Fabricate(:post, topic: pm_topic, user: user)
    pm_topic
  end

  let(:path) { "/discourse-ai/ai-bot/shared-ai-conversations" }
  let(:shared_conversation) { SharedAiConversation.share_conversation(user, user_pm_share) }

  def share_error(key)
    I18n.t("discourse_ai.share_ai.errors.#{key}")
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
          post_with_upload_1.update!(
            raw: "This is a post with a cool AI generated picture ![wow](#{upload_1.short_url})",
          )
          post_with_upload_2.update!(
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
          shared_conversation.target.posts.first.update!(
            raw: "This is a post with a cool AI generated picture ![wow](#{upload_1.short_url})",
          )
          shared_conversation.target.posts.second.update!(
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
      expect(response).not_to have_http_status(:success)
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
      expect(response.headers["Cache-Control"]).to eq("max-age=60, public")
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
      expect(response.body).not_to include("Translation missing")
    end

    it "is also able to render in json format" do
      get "#{path}/#{shared_conversation.share_key}.json"
      expect(response.parsed_body["llm_name"]).to eq("Claude-2")
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
    end

    it "returns an error if the shared conversation is not found" do
      get "#{path}/123"
      expect(response).to have_http_status(:not_found)
    end
  end
end
