# frozen_string_literal: true

RSpec.describe WebArtifactsController do
  fab!(:user)
  fab!(:admin)
  fab!(:topic) { Fabricate(:private_message_topic, user: user) }
  fab!(:pm_post) { Fabricate(:post, user: user, topic: topic) }
  fab!(:artifact) do
    Fabricate(:web_artifact, user: user, post: pm_post, metadata: { "public" => false })
  end

  describe "#show" do
    before { SiteSetting.web_artifact_security = "strict" }

    it "returns 404 when web_artifact_security is disabled" do
      SiteSetting.web_artifact_security = "disabled"
      get "/w/#{artifact.id}"
      expect(response.status).to eq(404)
    end

    it "returns 404 when artifact does not exist" do
      get "/w/999999"
      expect(response.status).to eq(404)
    end

    it "returns 404 when user cannot see the post" do
      get "/w/#{artifact.id}"
      expect(response.status).to eq(404)
    end

    it "returns 404 for orphaned non-public artifact (null post_id)" do
      orphan = Fabricate(:web_artifact, user: user, post: nil)
      other_user = Fabricate(:user)
      sign_in(other_user)
      get "/w/#{orphan.id}"
      expect(response.status).to eq(404)
    end

    it "shows artifact when user can see the post" do
      sign_in(user)
      get "/w/#{artifact.id}"
      expect(response.status).to eq(200)
      expect(response.body).to include("Hello World").or include("Test Content")
    end

    it "shows public artifacts without authentication" do
      artifact.update!(metadata: { "public" => true })
      get "/w/#{artifact.id}"
      expect(response.status).to eq(200)
    end

    it "shows a specific version" do
      version = artifact.create_new_version(html: "<div>Version 1</div>", change_description: "v1")
      sign_in(user)
      get "/w/#{artifact.id}/#{version.version_number}"
      expect(response.status).to eq(200)
      expect(response.body).to include("Version 1")
    end

    it "returns 404 for non-existent version" do
      sign_in(user)
      get "/w/#{artifact.id}/999"
      expect(response.status).to eq(404)
    end

    it "sets security headers" do
      artifact.update!(metadata: { "public" => true })
      get "/w/#{artifact.id}"
      expect(response.headers["Content-Security-Policy"]).to include("script-src")
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
      expect(response.headers["Cross-Origin-Opener-Policy"]).to eq("same-origin")
    end

    it "removes security headers and disables crawling" do
      sign_in(user)
      get "/w/#{artifact.id}"
      expect(response.headers["X-Frame-Options"]).to eq(nil)
      expect(response.headers["Content-Security-Policy"]).to include("unsafe-inline")
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
    end

    it "forces a same-origin opener policy regardless of site setting" do
      SiteSetting.cross_origin_opener_policy_header = "unsafe-none"

      sign_in(user)
      get "/w/#{artifact.id}"

      expect(response.status).to eq(200)
      expect(response.headers["Cross-Origin-Opener-Policy"]).to eq("same-origin")
    end

    it "sanitizes CSS to prevent style tag breakout" do
      sign_in(user)
      malicious_css = '</style><script>alert("XSS from CSS")</script><style>'
      artifact.update!(css: malicious_css)

      get "/w/#{artifact.id}"
      expect(response.status).to eq(200)

      untrusted_html = Nokogiri.HTML5(response.body).at_css("iframe")["srcdoc"]
      doc = Nokogiri.HTML5(untrusted_html)
      doc.css("script").each { |s| expect(s.text).not_to include("alert") }
      expect(doc.at_css("style").text).to include("alert")
    end

    it "validates event.source against the child iframe in the KV postMessage handler" do
      sign_in(user)
      get "/w/#{artifact.id}"
      expect(response.status).to eq(200)

      doc = Nokogiri.HTML5(response.body)
      parent_scripts = doc.css("body > script").map(&:text)
      kv_handler_script = parent_scripts.find { |s| s.include?("discourse-artifact-kv") }

      expect(kv_handler_script).to be_present
      expect(kv_handler_script).to match(/event\.source\s*!==?\s*\w+\.contentWindow/)
    end
  end

  describe "#create" do
    before { SiteSetting.web_artifact_security = "strict" }

    it "requires login" do
      post "/web-artifacts.json", params: { name: "test", html: "<p>hi</p>" }
      expect(response.status).to eq(403)
    end

    it "requires permission" do
      SiteSetting.web_artifact_allowed_groups = ""
      sign_in(user)
      post "/web-artifacts.json", params: { name: "test", html: "<p>hi</p>" }
      expect(response.status).to eq(403)
    end

    it "denies moderators with default allowed groups" do
      moderator = Fabricate(:moderator)
      sign_in(moderator)
      post "/web-artifacts.json", params: { name: "test", html: "<p>hi</p>" }
      expect(response.status).to eq(403)
    end

    it "creates artifact for admin" do
      sign_in(admin)
      post "/web-artifacts.json",
           params: {
             name: "My Artifact",
             html: "<p>hello</p>",
             css: "p { color: red; }",
             js: "console.log('hi');",
           }
      expect(response.status).to eq(201)
      json = response.parsed_body
      expect(json["id"]).to be_present

      artifact = WebArtifact.find(json["id"])
      expect(artifact.name).to eq("My Artifact")
      expect(artifact.html).to eq("<p>hello</p>")
      expect(artifact.user_id).to eq(admin.id)
      expect(artifact.post_id).to be_nil
    end

    it "creates artifact for user in allowed group" do
      group = Fabricate(:group)
      group.add(user)
      SiteSetting.web_artifact_allowed_groups = group.id.to_s
      sign_in(user)

      post "/web-artifacts.json", params: { name: "test", html: "<div>hi</div>" }
      expect(response.status).to eq(201)
    end

    it "returns 404 when web_artifact_security is disabled" do
      SiteSetting.web_artifact_security = "disabled"
      sign_in(admin)
      post "/web-artifacts.json", params: { name: "test", html: "<p>hi</p>" }
      expect(response.status).to eq(404)
    end
  end

  describe "#metadata" do
    before { SiteSetting.web_artifact_security = "strict" }

    it "returns artifact metadata for the owner" do
      sign_in(user)
      get "/web-artifacts/#{artifact.id}.json"
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["id"]).to eq(artifact.id)
      expect(json["name"]).to eq(artifact.name)
    end

    it "returns 403 for non-owner non-admin" do
      other_user = Fabricate(:user)
      sign_in(other_user)
      get "/web-artifacts/#{artifact.id}.json"
      expect(response.status).to eq(403)
    end

    it "returns artifact metadata for admin" do
      sign_in(admin)
      get "/web-artifacts/#{artifact.id}.json"
      expect(response.status).to eq(200)
    end
  end

  describe "#update" do
    before { SiteSetting.web_artifact_security = "strict" }

    it "creates a new version on update" do
      sign_in(user)
      put "/web-artifacts/#{artifact.id}.json",
          params: {
            html: "<p>updated</p>",
            css: ".x{color:red}",
            js: "",
            change_description: "tweak",
          }
      expect(response.status).to eq(204)

      version = artifact.versions.order(:version_number).last
      expect(version.html).to eq("<p>updated</p>")
      expect(version.change_description).to eq("tweak")
    end

    it "returns 403 for non-owner non-admin" do
      other_user = Fabricate(:user)
      sign_in(other_user)
      put "/web-artifacts/#{artifact.id}.json", params: { html: "<p>x</p>" }
      expect(response.status).to eq(403)
    end

    it "allows admin to edit any artifact" do
      sign_in(admin)
      put "/web-artifacts/#{artifact.id}.json", params: { html: "<p>by admin</p>" }
      expect(response.status).to eq(204)
    end
  end
end
