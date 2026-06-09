# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::ArtifactsController do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:topic) { Fabricate(:private_message_topic, user: user) }
  fab!(:pm_post) { Fabricate(:post, user: user, topic: topic) }
  fab!(:artifact) do
    AiArtifact.create!(
      user: user,
      post: pm_post,
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
    SiteSetting.ai_artifact_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
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
    end

    context "with version=latest" do
      it "returns the base content when the artifact has no versions" do
        sign_in(user)

        get "/discourse-ai/ai-bot/artifacts/#{artifact.id}/latest"

        expect(response.status).to eq(200)
        expect(parse_srcdoc(response.body)).to include(artifact.html)
      end

      it "returns the latest version when one exists" do
        artifact.create_new_version(html: "<div>v2</div>")
        sign_in(user)

        get "/discourse-ai/ai-bot/artifacts/#{artifact.id}/latest"

        expect(response.status).to eq(200)
        expect(parse_srcdoc(response.body)).to include("<div>v2</div>")
      end
    end

    context "with orphan artifact" do
      before { artifact.update!(post_id: nil) }

      it "returns 404 to anonymous viewers" do
        get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"

        expect(response.status).to eq(404)
      end

      it "returns 200 to the artifact owner" do
        sign_in(user)

        get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"

        expect(response.status).to eq(200)
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

    context "with JSON format" do
      it "returns 200 with the artifact attributes when the user can see the post" do
        sign_in(user)

        get "/discourse-ai/ai-bot/artifacts/#{artifact.id}/latest.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq(
          "id" => artifact.id,
          "name" => artifact.name,
          "html" => artifact.html,
          "css" => artifact.css,
          "js" => artifact.js,
        )
      end

      it "returns 200 to admins" do
        sign_in(admin)

        get "/discourse-ai/ai-bot/artifacts/#{artifact.id}/latest.json"

        expect(response.status).to eq(200)
      end

      it "returns 404 to users who cannot see the post" do
        sign_in(Fabricate(:user))

        get "/discourse-ai/ai-bot/artifacts/#{artifact.id}/latest.json"

        expect(response.status).to eq(404)
      end

      it "returns the latest version attributes when a newer version exists" do
        artifact.create_new_version(html: "<div>v2</div>", css: ".x{}", js: "console.log(2)")
        sign_in(user)

        get "/discourse-ai/ai-bot/artifacts/#{artifact.id}/latest.json"

        expect(response.parsed_body).to include(
          "html" => "<div>v2</div>",
          "css" => ".x{}",
          "js" => "console.log(2)",
        )
      end
    end
  end

  describe "#create" do
    let(:valid_params) { { name: "Composer artifact", html: "<p>hi</p>", css: "", js: "" } }

    it "returns 403 to anonymous users" do
      post "/discourse-ai/ai-bot/artifacts.json", params: valid_params

      expect(response.status).to eq(403)
    end

    it "returns 403 to users who are not in the `ai_artifact_allowed_groups` site setting" do
      SiteSetting.ai_artifact_allowed_groups = ""
      sign_in(user)

      post "/discourse-ai/ai-bot/artifacts.json", params: valid_params

      expect(response.status).to eq(403)
    end

    it "returns 404 when the `ai_artifact_security` site setting is disabled" do
      SiteSetting.ai_artifact_security = "disabled"
      sign_in(admin)

      post "/discourse-ai/ai-bot/artifacts.json", params: valid_params

      expect(response.status).to eq(404)
    end

    it "returns 200 and creates an artifact not associated to a post for admins" do
      sign_in(admin)

      post "/discourse-ai/ai-bot/artifacts.json", params: valid_params

      expect(response.status).to eq(200)
      created = AiArtifact.find(response.parsed_body["id"])
      expect(created).to have_attributes(
        user_id: admin.id,
        post_id: nil,
        name: "Composer artifact",
        html: "<p>hi</p>",
      )
    end

    it "returns 200 and creates an artifact not associated to a post for users in the `ai_artifact_allowed_groups` site setting" do
      group = Fabricate(:group)
      group.add(user)
      SiteSetting.ai_artifact_allowed_groups = group.id.to_s
      sign_in(user)

      post "/discourse-ai/ai-bot/artifacts.json", params: valid_params

      expect(response.status).to eq(200)
      expect(AiArtifact.find(response.parsed_body["id"]).user_id).to eq(user.id)
    end
  end

  describe "#update" do
    let(:valid_params) { { html: "<p>new</p>", css: ".x{color:red}", js: "" } }

    it "returns 200 and appends a new version when called by the owner" do
      sign_in(user)

      expect {
        put "/discourse-ai/ai-bot/artifacts/#{artifact.id}.json", params: valid_params
      }.to change { artifact.versions.count }.by(1)

      expect(response.status).to eq(200)
      expect(artifact.versions.order(:version_number).last.html).to eq("<p>new</p>")
    end

    it "returns 200 when called by an admin who does not own the artifact" do
      sign_in(admin)

      put "/discourse-ai/ai-bot/artifacts/#{artifact.id}.json", params: valid_params

      expect(response.status).to eq(200)
    end

    it "returns 403 to users who do not own the artifact" do
      sign_in(Fabricate(:user))

      put "/discourse-ai/ai-bot/artifacts/#{artifact.id}.json", params: valid_params

      expect(response.status).to eq(403)
    end

    it "returns 404 when the `ai_artifact_security` site setting is disabled" do
      SiteSetting.ai_artifact_security = "disabled"
      sign_in(user)

      put "/discourse-ai/ai-bot/artifacts/#{artifact.id}.json", params: valid_params

      expect(response.status).to eq(404)
    end
  end
end
