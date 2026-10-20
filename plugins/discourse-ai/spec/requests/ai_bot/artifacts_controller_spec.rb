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

  describe "#embed" do
    it "renders current and explicit versions without an authenticated bridge even for a signed-in owner" do
      artifact.update!(metadata: { public: true })
      public_topic = Fabricate(:topic, user: user)
      public_post = Fabricate(:post, user: user, topic: public_topic)
      artifact.update!(post: public_post)
      version = artifact.create_new_version(html: "<p>Old public version</p>")
      artifact.update!(html: "<p>Current public version</p>")
      sign_in(user)

      get AiArtifact.embed_url(artifact.id)
      expect(response.status).to eq(200)
      expect(parse_srcdoc(response.body)).to include(artifact.html)
      expect(response.headers["X-Frame-Options"]).to be_nil
      expect(response.headers["Referrer-Policy"]).to eq("no-referrer")
      expect(response.headers["Cache-Control"]).to eq("no-store")
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
      expect(response.body).not_to include(
        "csrf-token",
        "discourse-artifact-kv",
        "_discourse_user_data",
      )
      expect(Nokogiri.HTML5(response.body).css("body > script")).to be_empty

      get AiArtifact.embed_url(artifact.id, version.version_number)
      expect(response.status).to eq(200)
      expect(parse_srcdoc(response.body)).to include(version.html)
      expect(parse_srcdoc(response.body)).not_to include(artifact.html)
      expect(AiArtifactShare.where(ai_artifact: artifact)).not_to exist

      get artifact.url
      expect(response.status).to eq(200)
      expect(response.body).to include("_discourse_user_data", "discourse-artifact-kv")
    end

    it "rejects an owner's private source, unpublished PM, missing versions, and trashed sources" do
      sign_in(user)
      get AiArtifact.embed_url(artifact.id)
      expect(response.status).to eq(404)

      artifact.update!(metadata: { public: true })
      get AiArtifact.embed_url(artifact.id)
      expect(response.status).to eq(404)

      public_topic = Fabricate(:topic, user: user)
      public_post = Fabricate(:post, user: user, topic: public_topic)
      artifact.update!(post: public_post)
      get AiArtifact.embed_url(artifact.id, 999)
      expect(response.status).to eq(404)
      get "#{AiArtifact.embed_url(artifact.id).delete_suffix("/embed")}/1garbage/embed"
      expect(response.status).to eq(404)
      get AiArtifact.embed_url("9223372036854775808")
      expect(response.status).to eq(404)
      get AiArtifact.embed_url(artifact.id, "2147483648")
      expect(response.status).to eq(404)
      public_post.trash!
      get AiArtifact.embed_url(artifact.id)
      expect(response.status).to eq(404)
    end

    it "honors the global login wall for a public source" do
      public_topic = Fabricate(:topic, user: user)
      artifact.update!(post: Fabricate(:post, user: user, topic: public_topic))
      SiteSetting.login_required = true

      get AiArtifact.embed_url(artifact.id)
      expect(response).to redirect_to("/login")
    end
  end

  describe "#shared" do
    it "renders only the shared artifact without the authenticated bridge" do
      SiteSetting.ai_bot_enabled = true
      group = Fabricate(:group)
      group.add(user)
      SiteSetting.ai_bot_public_sharing_allowed_groups = group.id.to_s
      artifact.update!(name: "<script>Untrusted title</script>")
      share = AiArtifactShare.new(ai_artifact: artifact, user: user)
      share.assign_attributes(share.snapshot_attributes(version_number: 0))
      share.save!

      get share.url

      expect(response.status).to eq(200)
      document = Nokogiri.HTML5(response.body)
      expect(document.css("body > *").map(&:name)).to eq(["iframe"])
      frame = document.at_css("body > iframe")
      expect(frame["title"]).to eq(artifact.name)
      expect(frame["sandbox"]).to eq("allow-scripts allow-forms")
      expect(frame["srcdoc"]).to include(artifact.html)
      expect(document.at_css("title").text).to eq(artifact.name)
      expect(document.css("body > script")).to be_empty
      expect(response.body).not_to include("csrf-token", "discourse-artifact-kv")
    end
  end

  describe "#shared_metadata" do
    fab!(:group)

    before do
      SiteSetting.ai_bot_enabled = true
      group.add(user)
      SiteSetting.ai_bot_public_sharing_allowed_groups = group.id.to_s
    end

    it "returns only the pinned snapshot name without exposing the source" do
      share = AiArtifactShare.new(ai_artifact: artifact, user: user)
      share.assign_attributes(share.snapshot_attributes(version_number: 0))
      share.save!
      artifact.update!(name: "Changed private source", html: "<p>New private source</p>")
      artifact.create_new_version(html: "<p>Private future version</p>")

      get "/discourse-ai/ai-bot/artifact-shares/#{share.share_key}/metadata.json"

      expect(response.status).to eq(200)
      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body).to eq({ "name" => share.name })
      expect(response.headers["Cache-Control"]).to eq("no-store")
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
    end

    it "hides missing shares and shares after group, source, or site access is lost" do
      share = AiArtifactShare.new(ai_artifact: artifact, user: user)
      share.assign_attributes(share.snapshot_attributes(version_number: 0))
      share.save!
      path = "/discourse-ai/ai-bot/artifact-shares/#{share.share_key}/metadata.json"

      get "/discourse-ai/ai-bot/artifact-shares/unknown/metadata.json"
      expect(response.status).to eq(404)
      get path
      expect(response.parsed_body).to eq({ "name" => share.name })

      group.remove(user)
      get path
      expect(response.status).to eq(404)
      group.add(user)
      post.trash!
      get path
      expect(response.status).to eq(404)
      post.recover!
      SiteSetting.ai_bot_enabled = false
      get path
      expect(response.status).to eq(404)
      SiteSetting.ai_bot_enabled = true
      SiteSetting.ai_artifact_security = "disabled"
      get path
      expect(response.status).to eq(404)
    end

    it "keeps the global login wall for an anonymous metadata request" do
      share = AiArtifactShare.new(ai_artifact: artifact, user: user)
      share.assign_attributes(share.snapshot_attributes(version_number: 0))
      share.save!
      SiteSetting.login_required = true

      get "/discourse-ai/ai-bot/artifact-shares/#{share.share_key}/metadata.json"

      expect(response.status).to eq(403)
      expect(response.parsed_body["error_type"]).to eq("not_logged_in")
    end
  end

  describe "#metadata" do
    it "returns only the source name for base and existing versions to a permitted viewer" do
      version = artifact.create_new_version(html: "<p>Secret version</p>")
      sign_in(user)
      path = "/discourse-ai/ai-bot/artifacts/#{artifact.id}/metadata.json"

      get path
      expect(response.status).to eq(200)
      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body).to eq({ "name" => artifact.name })
      expect(response.headers["Cache-Control"]).to eq("no-store")
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")

      ["0", version.version_number.to_s].each do |requested_version|
        get path, params: { version: requested_version }
        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq({ "name" => artifact.name })
      end
    end

    it "returns a public source name to guests and hides a trashed source" do
      artifact.update!(metadata: { public: true })
      path = "/discourse-ai/ai-bot/artifacts/#{artifact.id}/metadata.json"

      get path
      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq({ "name" => artifact.name })

      topic.trash!
      get path
      expect(response.status).to eq(404)
    end

    it "rejects inaccessible sources, invalid IDs, and invalid or missing versions" do
      path = "/discourse-ai/ai-bot/artifacts/#{artifact.id}/metadata.json"
      get path
      expect(response.status).to eq(404)

      sign_in(user)
      %w[0 1garbage 999999999999999999999999999999999999999999].each do |bad_id|
        get "/discourse-ai/ai-bot/artifacts/#{bad_id}/metadata.json"
        expect(response.status).to eq(404)
      end
      [
        "1garbage",
        "-1",
        "01",
        "",
        "999",
        "999999999999999999999999999999999999999999",
      ].each do |bad_version|
        get path, params: { version: bad_version }
        expect(response.status).to eq(404)
      end
      get path, params: { version: %w[0 1] }
      expect(response.status).to eq(404)

      topic.trash!
      get path
      expect(response.status).to eq(404)
    end

    it "honors site security and the global login wall" do
      artifact.update!(metadata: { public: true })
      path = "/discourse-ai/ai-bot/artifacts/#{artifact.id}/metadata.json"
      SiteSetting.ai_artifact_security = "disabled"
      get path
      expect(response.status).to eq(404)

      SiteSetting.ai_artifact_security = "strict"
      SiteSetting.login_required = true
      get path
      expect(response.status).to eq(403)
      expect(response.parsed_body["error_type"]).to eq("not_logged_in")
    end
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
      bot_user = Fabricate(:ai_agent, default_llm: llm_model).ensure_user!
      toggle_enabled_bots(bots: [llm_model])
      SiteSetting.ai_bot_enabled = true
      SiteSetting.ai_bot_public_sharing_allowed_groups = "10"
      Group.user_trust_level_change!(user.id, user.trust_level)

      topic.topic_allowed_users.where.not(user_id: user.id).delete_all
      topic.topic_allowed_users.create!(user: bot_user)
      post.update_columns(
        cooked: "<div class='ai-artifact' data-ai-artifact-id='#{artifact.id}'></div>",
      )

      public_key_value =
        Fabricate(
          :ai_artifact_key_value,
          ai_artifact: artifact,
          user: user,
          key: "shared_public_key",
          value: "shared_public_value",
          public: true,
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

      get "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}.json",
          params: {
            all_users: true,
          }
      key_values_response = { status: response.status, body: response.body }

      aggregate_failures do
        expect(shared_conversation_status).to eq(404)
        expect(artifact_response[:status]).to eq(404)
        expect(artifact_response[:body]).not_to include(artifact.html)
        expect(artifact_version_response[:status]).to eq(404)
        expect(artifact_version_response[:body]).not_to include(artifact_version.html)
        expect(key_values_response[:status]).to eq(404)
        expect(key_values_response[:body]).not_to include(public_key_value.value)
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

    it "restricts authenticated runtime framing to the forum and disables crawling" do
      sign_in(user)
      get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"
      expect(response.headers["X-Frame-Options"]).to eq("SAMEORIGIN")
      expect(response.headers["Content-Security-Policy"]).to include(
        "unsafe-inline",
        "frame-ancestors 'self'",
      )
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
