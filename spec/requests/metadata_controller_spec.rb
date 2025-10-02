# frozen_string_literal: true

RSpec.describe MetadataController do
  describe "manifest.webmanifest" do
    before { SiteIconManager.enable }

    let(:upload) do
      UploadCreator.new(file_from_fixtures("smallest.png"), "logo.png").create_for(
        Discourse.system_user.id,
      )
    end

    it "returns the right output" do
      title = "MyApp"
      SiteSetting.title = title
      SiteSetting.manifest_icon = upload

      get "/manifest.webmanifest"
      expect(response.status).to eq(200)
      expect(response.media_type).to eq("application/manifest+json")
      expect(response.headers["Cache-Control"]).to eq("max-age=60, private")

      manifest = JSON.parse(response.body)

      expect(manifest["name"]).to eq(title)

      expect(manifest["icons"].first["src"]).to eq(
        UrlHelper.absolute(SiteSetting.site_manifest_icon_url),
      )
    end

    it "includes share target configuration" do
      get "/manifest.webmanifest"
      expect(response.status).to eq(200)
      manifest = JSON.parse(response.body)
      expect(manifest["share_target"]).to be_present
      expect(manifest["share_target"]["params"]["title"]).to eq("title")
      expect(manifest["share_target"]["params"]["text"]).to eq("body")
      expect(manifest["share_target"]["params"]["url"]).to eq("title")
    end

    it "can guess mime types" do
      upload =
        UploadCreator.new(file_from_fixtures("logo.jpg"), "logo.jpg").create_for(
          Discourse.system_user.id,
        )

      SiteSetting.manifest_icon = upload
      get "/manifest.webmanifest"

      expect(response.status).to eq(200)
      manifest = JSON.parse(response.body)
      expect(manifest["icons"].first["type"]).to eq("image/jpeg")
    end

    it "defaults to png" do
      SiteSetting.manifest_icon = upload
      get "/manifest.webmanifest"
      expect(response.status).to eq(200)
      manifest = JSON.parse(response.body)
      expect(manifest["icons"].first["type"]).to eq("image/png")
    end

    it "defaults to display standalone for Android" do
      get "/manifest.webmanifest",
          params: {
          },
          headers: {
            "USER-AGENT" =>
              "Mozilla/5.0 (Linux; Android 7.0; SM-G892A Build/NRD90M; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/67.0.3396.87 Mobile Safari/537.36",
          }
      manifest = JSON.parse(response.body)
      expect(manifest["display"]).to eq("standalone")
    end

    it "defaults to display standalone for iPhone" do
      get "/manifest.webmanifest",
          params: {
          },
          headers: {
            "USER-AGENT" =>
              "Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1",
          }
      manifest = JSON.parse(response.body)
      expect(manifest["display"]).to eq("standalone")
    end

    it "can be changed to display browser for iPhones using a site setting" do
      SiteSetting.pwa_display_browser_regex = "iPhone"

      get "/manifest.webmanifest",
          params: {
          },
          headers: {
            "USER-AGENT" =>
              "Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1",
          }
      manifest = JSON.parse(response.body)
      expect(manifest["display"]).to eq("browser")
    end

    it "uses the short_title if it is set" do
      title = "FooBarBaz Forum"
      SiteSetting.title = title

      get "/manifest.webmanifest"
      expect(response.status).to eq(200)
      manifest = JSON.parse(response.body)
      expect(manifest["short_name"]).to eq("FooBarBaz")

      SiteSetting.short_title = "foo"

      get "/manifest.webmanifest"
      expect(response.status).to eq(200)
      manifest = JSON.parse(response.body)
      expect(manifest["short_name"]).to eq("foo")
    end

    it "contains valid shortcuts by default" do
      get "/manifest.webmanifest"
      expect(response.status).to eq(200)
      manifest = JSON.parse(response.body)
      expect(manifest["shortcuts"].size).to be > 0
      expect { URI.parse(manifest["shortcuts"][0]["url"]) }.not_to raise_error
    end
  end

  describe "opensearch.xml" do
    fab!(:upload)

    it "returns the right output" do
      title = "MyApp"
      SiteSetting.title = title
      SiteSetting.favicon = upload
      get "/opensearch.xml"

      expect(response.headers["Cache-Control"]).to eq("max-age=60, private")

      expect(response.status).to eq(200)
      expect(response.body).to include(title)
      expect(response.body).to include("/search?q={searchTerms}")
      expect(response.body).to include("image/png")
      expect(response.body).to include(UrlHelper.absolute(upload.url))
      expect(response.media_type).to eq("application/xml")
    end
  end

  describe "#app_association_android" do
    it "returns 404 by default" do
      get "/.well-known/assetlinks.json"
      expect(response.status).to eq(404)
    end

    it "returns the right output" do
      SiteSetting.app_association_android = <<~JSON
        [{
          "relation": ["delegate_permission/common.handle_all_urls"],
          "target" : { "namespace": "android_app", "package_name": "com.example.app",
                       "sha256_cert_fingerprints": ["hash_of_app_certificate"] }
        }]
      JSON
      get "/.well-known/assetlinks.json"

      expect(response.headers["Cache-Control"]).to eq("max-age=60, private")

      expect(response.status).to eq(200)
      expect(response.body).to include("hash_of_app_certificate")
      expect(response.body).to include("com.example.app")
      expect(response.media_type).to eq("application/json")
    end
  end

  describe "#app_association_ios" do
    it "returns 404 by default" do
      get "/apple-app-site-association"
      expect(response.status).to eq(404)

      get "/.well-known/apple-app-site-association"
      expect(response.status).to eq(404)
    end

    it "returns the right output" do
      SiteSetting.app_association_ios = <<~JSON
        {
          "applinks": {
            "apps": []
          }
        }
      JSON
      get "/apple-app-site-association"

      expect(response.status).to eq(200)
      expect(response.body).to include("applinks")
      expect(response.media_type).to eq("application/json")
      expect(response.headers["Cache-Control"]).to eq("max-age=60, private")

      get "/.well-known/apple-app-site-association"

      expect(response.status).to eq(200)
      expect(response.body).to include("applinks")
      expect(response.media_type).to eq("application/json")
      expect(response.headers["Cache-Control"]).to eq("max-age=60, private")

      get "/apple-app-site-association.json"
      expect(response.status).to eq(404)
    end
  end

  describe "#discourse_id_challenge" do
    context "when challenge token is present in Redis" do
      let(:token) { SecureRandom.hex(16) }

      before { Discourse.redis.setex("discourse_id_challenge_token", 600, token) }
      after { Discourse.redis.del("discourse_id_challenge_token") }

      it "returns the challenge token and domain" do
        get "/.well-known/discourse-id-challenge"

        expect(response.status).to eq(200)
        expect(response.media_type).to eq("application/json")
        expect(response.headers["Cache-Control"]).to eq("max-age=300, private")

        json = response.parsed_body
        expect(json["token"]).to eq(token)
        expect(json["domain"]).to eq(Discourse.current_hostname)
        expect(json).to_not have_key("path")
      end

      context "when using subfolder" do
        before { set_subfolder "/f" }

        it "also returns the path" do
          get "/.well-known/discourse-id-challenge"

          expect(response.status).to eq(200)
          expect(response.media_type).to eq("application/json")
          expect(response.headers["Cache-Control"]).to eq("max-age=300, private")

          json = response.parsed_body
          expect(json["token"]).to eq(token)
          expect(json["domain"]).to eq(Discourse.current_hostname)
          expect(json["path"]).to eq(Discourse.base_path)
        end
      end
    end

    context "when no challenge token is present" do
      before { Discourse.redis.del("discourse_id_challenge_token") }

      it "returns 404" do
        get "/.well-known/discourse-id-challenge"

        expect(response.status).to eq(404)
        expect(response.cache_control).to eq({})
      end
    end
  end
end
