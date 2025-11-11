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

    context "with public artifact" do
      before { artifact.update!(metadata: { public: true }) }

      it "shows artifact without authentication" do
        get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"
        expect(response.status).to eq(200)
        expect(parse_srcdoc(response.body)).to include(artifact.html)
      end
    end

    it "removes security headers and disables crawling" do
      sign_in(user)
      get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"
      expect(response.headers["X-Frame-Options"]).to eq(nil)
      expect(response.headers["Content-Security-Policy"]).to include("unsafe-inline")
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
    end
  end
end
