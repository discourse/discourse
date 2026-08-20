# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::ArtifactsController do
  fab!(:user)
  fab!(:topic) { Fabricate(:private_message_topic, user: user) }
  fab!(:post) { Fabricate(:post, user: user, topic: topic) }
  fab!(:artifact) do
    AiArtifact.create!(
      user: user,
      post: post,
      name: "Test Artifact",
      html: "<div>Hello World</div>",
      css: "div { color: blue; }",
      js: "console.log('test');",
      metadata: {
        public: false,
      },
    )
  end

  def parse_srcdoc(html)
    Nokogiri.HTML5(html).at_css("iframe")["srcdoc"]
  end

  before do
    enable_current_plugin
    SiteSetting.ai_artifact_security = "strict"
  end

  describe "#show" do
    it "returns 404 when discourse_ai is disabled" do
      SiteSetting.discourse_ai_enabled = false
      get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"
      expect(response.status).to eq(404)
    end

    it "returns 404 when ai_artifact_security disables it" do
      SiteSetting.ai_artifact_security = "disabled"
      get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"
      expect(response.status).to eq(404)
    end

    context "with private artifact" do
      it "returns 404 when user cannot see the post" do
        get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"
        expect(response.status).to eq(404)
      end

      it "shows artifact when user can see the post" do
        sign_in(user)
        get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"
        expect(response.status).to eq(200)
        untrusted_html = parse_srcdoc(response.body)
        expect(untrusted_html).to include(artifact.html)
        expect(untrusted_html).to include(artifact.css)
        expect(untrusted_html).to include(artifact.js)
      end

      it "can also find an artifact by its version" do
        sign_in(user)

        version = artifact.create_new_version(html: "<div>Was Updated</div>")

        get "/discourse-ai/ai-bot/artifacts/#{artifact.id}/#{version.version_number}"
        expect(response.status).to eq(200)
        untrusted_html = parse_srcdoc(response.body)
        expect(untrusted_html).to include("Was Updated")
        expect(untrusted_html).to include(artifact.css)
        expect(untrusted_html).to include(artifact.js)
      end
    end

    context "with non-PM artifact" do
      fab!(:regular_topic) { Fabricate(:topic, user: user) }
      fab!(:regular_post) { Fabricate(:post, user: user, topic: regular_topic) }
      fab!(:regular_artifact) do
        AiArtifact.create!(
          user: user,
          post: regular_post,
          name: "Regular Topic Artifact",
          html: "<div>Regular</div>",
          css: "",
          js: "",
          metadata: {
            public: false,
          },
        )
      end

      it "shows artifact to user who can see the post" do
        sign_in(user)
        get "/discourse-ai/ai-bot/artifacts/#{regular_artifact.id}"
        expect(response.status).to eq(200)
        expect(parse_srcdoc(response.body)).to include(regular_artifact.html)
      end

      it "returns 404 when user cannot see the post" do
        other_user = Fabricate(:user)
        regular_topic.update!(category: Fabricate(:private_category, group: Fabricate(:group)))
        sign_in(other_user)
        get "/discourse-ai/ai-bot/artifacts/#{regular_artifact.id}"
        expect(response.status).to eq(404)
      end
    end

    context "with public artifact" do
      before { artifact.update!(metadata: { public: true }) }

      it "shows artifact without authentication" do
        get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"
        expect(response.status).to eq(200)
        expect(parse_srcdoc(response.body)).to include(artifact.html)
      end

      it "returns 404 when the source topic has been trashed" do
        topic.trash!

        get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"
        expect(response.status).to eq(404)
      end
    end

    it "hides artifacts and future versions when their conversation share is invalidated" do
      llm_model = Fabricate(:llm_model, name: "artifact-sharing-model")
      toggle_enabled_bots(bots: [llm_model])
      SiteSetting.ai_bot_enabled = true
      SiteSetting.ai_bot_public_sharing_allowed_groups = "10"
      Group.user_trust_level_change!(user.id, user.trust_level)

      bot_user = llm_model.reload.user
      topic.topic_allowed_users.where.not(user_id: user.id).delete_all
      topic.topic_allowed_users.create!(user: bot_user)
      post.update_columns(
        cooked: "<div class='ai-artifact' data-ai-artifact-id='#{artifact.id}'></div>",
      )

      shared_conversation = SharedAiConversation.share_conversation(user, topic)
      expect(shared_conversation.publicly_visible?).to eq(true)
      expect(artifact.reload.public?).to eq(true)

      topic.topic_allowed_users.create!(user: Fabricate(:user))
      artifact_version =
        artifact.create_new_version(html: "<div>Future private artifact version</div>")

      get "/discourse-ai/ai-bot/shared-ai-conversations/#{shared_conversation.share_key}.json"
      shared_conversation_status = response.status

      get artifact.url
      artifact_response = {
        status: response.status,
        body: response.status == 200 ? parse_srcdoc(response.body) : response.body,
      }

      get AiArtifact.url(artifact.id, artifact_version.version_number)
      artifact_version_response = {
        status: response.status,
        body: response.status == 200 ? parse_srcdoc(response.body) : response.body,
      }

      aggregate_failures do
        expect(shared_conversation_status).to eq(404)
        expect(artifact_response[:status]).to eq(404)
        expect(artifact_response[:body]).not_to include(artifact.html)
        expect(artifact_version_response[:status]).to eq(404)
        expect(artifact_version_response[:body]).not_to include(artifact_version.html)
      end
    end

    it "sanitizes CSS to prevent style tag breakout" do
      sign_in(user)
      malicious_css = '</style><script>alert("XSS from CSS")</script><style>'
      artifact.update!(css: malicious_css)

      get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"
      expect(response.status).to eq(200)

      untrusted_html = parse_srcdoc(response.body)
      doc = Nokogiri.HTML5(untrusted_html)
      script_contents = doc.css("script").map(&:text)
      script_contents.each { |s| expect(s).not_to include("alert") }

      style_tag = doc.at_css("style")
      expect(style_tag.text).to include("alert")
    end

    it "removes security headers and disables crawling" do
      sign_in(user)
      get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"
      expect(response.headers["X-Frame-Options"]).to eq(nil)
      expect(response.headers["Content-Security-Policy"]).to include("unsafe-inline")
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
    end

    it "forces a same-origin opener policy for artifact pages" do
      SiteSetting.cross_origin_opener_policy_header = "unsafe-none"

      sign_in(user)
      get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"

      expect(response.status).to eq(200)
      expect(response.headers["Cross-Origin-Opener-Policy"]).to eq("same-origin")
    end

    it "validates event.source against the child iframe in the KV postMessage handler" do
      sign_in(user)
      get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"
      expect(response.status).to eq(200)

      doc = Nokogiri.HTML5(response.body)
      parent_scripts = doc.css("body > script").map(&:text)
      kv_handler_script = parent_scripts.find { |s| s.include?("discourse-artifact-kv") }

      expect(kv_handler_script).to be_present
      expect(kv_handler_script).to match(/event\.source\s*!==?\s*\w+\.contentWindow/)
    end
  end
end
