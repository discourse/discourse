# frozen_string_literal: true

RSpec.describe StaticController do
  fab!(:upload)

  describe "#favicon" do
    let(:filename) { "smallest.png" }
    let(:file) { file_from_fixtures(filename) }

    let(:upload) { UploadCreator.new(file, filename).create_for(Discourse.system_user.id) }

    after { Discourse.redis.scan_each(match: "memoize_*").each { |key| Discourse.redis.del(key) } }

    context "with local store" do
      it "returns the default favicon if favicon has not been configured" do
        get "/favicon/proxied"

        expect(response.status).to eq(200)
        expect(response.media_type).to eq("image/png")
        expect(response.body.bytesize).to eq(SiteIconManager.favicon.filesize)
      end

      it "returns the configured favicon" do
        SiteSetting.favicon = upload

        get "/favicon/proxied"

        expect(response.status).to eq(200)
        expect(response.media_type).to eq("image/png")
        expect(response.body.bytesize).to eq(upload.filesize)
      end
    end

    context "with external store" do
      let(:upload) do
        Upload.create!(
          url: "//s3-upload-bucket.s3-us-east-1.amazonaws.com/somewhere/a.png",
          original_filename: filename,
          filesize: file.size,
          user_id: Discourse.system_user.id,
        )
      end

      before { setup_s3 }

      it "can proxy a favicon correctly" do
        SiteSetting.favicon = upload

        stub_request(:get, "https:/#{upload.url}").to_return(status: 200, body: file)

        get "/favicon/proxied"

        expect(response.status).to eq(200)
        expect(response.media_type).to eq("image/png")
        expect(response.body.bytesize).to eq(upload.filesize)
      end

      context "when favicon fails to load" do
        before { FileHelper.stubs(:download).raises(SocketError) }

        it "creates an admin notice" do
          expect { get "/favicon/proxied" }.to change { AdminNotice.problem.count }.by(1)
        end
      end
    end
  end

  describe "#cdn_asset" do
    let(:site) { RailsMultisite::ConnectionManagement.current_db }

    it "can serve assets" do
      begin
        assets_path = Rails.root.join("public/assets")

        FileUtils.mkdir_p(assets_path)

        file_path = assets_path.join("test.js.br")
        File.write(file_path, "fake brotli file")

        get "/cdn_asset/#{site}/test.js.br"

        expect(response.status).to eq(200)
        expect(response.headers["Cache-Control"]).to match(/public/)
      ensure
        File.delete(file_path)
      end
    end
  end

  describe "#show" do
    before do
      post = create_post
      SiteSetting.tos_topic_id = post.topic.id
      SiteSetting.guidelines_topic_id = post.topic.id
      SiteSetting.privacy_topic_id = post.topic.id
    end

    context "with a static file that's present" do
      it "should return the right response for /faq" do
        get "/faq"

        expect(response.status).to eq(200)
        expect(response.body).to include(I18n.t("js.faq"))
        expect(response.body).to include("<title>FAQ - Discourse</title>")
      end
    end

    [
      ["tos", :tos_url, I18n.t("js.tos")],
      ["privacy", :privacy_policy_url, I18n.t("js.privacy")],
    ].each do |id, setting_name, text|
      context "with #{id}" do
        context "when #{setting_name} site setting is NOT set" do
          it "renders the #{id} page" do
            get "/#{id}"

            expect(response.status).to eq(200)
            expect(response.body).to include(text)
          end
        end

        context "when #{setting_name} site setting is set" do
          before { SiteSetting.set(setting_name, "http://example.com/page") }

          it "redirects to the #{setting_name}" do
            get "/#{id}"

            expect(response).to redirect_to("http://example.com/page")
          end
        end
      end
    end

    context "with a missing file" do
      it "should respond 404" do
        get "/static/does-not-exist"
        expect(response.status).to eq(404)
      end

      context "with modal pages" do
        it "should return the right response for /signup" do
          get "/signup"
          expect(response.status).to eq(200)
        end

        it "should return the right response for /password-reset" do
          get "/password-reset"
          expect(response.status).to eq(200)
        end
      end
    end

    it "should redirect to / when logged in and path is /login" do
      sign_in(Fabricate(:user))
      get "/login"
      expect(response).to redirect_to("/")
    end

    it "should display the login template when login is required" do
      SiteSetting.login_required = true

      get "/login"

      expect(response.status).to eq(200)

      expect(response.body).to include(
        PrettyText.cook(I18n.t("login_required.welcome_message", title: SiteSetting.title)),
      )
    end

    context "when login_required is enabled" do
      before { SiteSetting.login_required = true }

      %w[faq guidelines rules conduct].each do |page_name|
        it "#{page_name} page redirects to login page for anon" do
          get "/#{page_name}"
          expect(response).to redirect_to "/login"
        end

        it "#{page_name} page loads for logged in user" do
          sign_in(Fabricate(:user))

          get "/#{page_name}"

          expect(response.status).to eq(200)
          expect(response.body).to include(I18n.t("js.guidelines"))
        end
      end
    end

    context "with crawler view" do
      it "should include correct title" do
        get "/faq", headers: { "HTTP_USER_AGENT" => "Googlebot" }
        expect(response.status).to eq(200)
        expect(response.body).to include("<title>FAQ - Discourse</title>")
      end
    end

    context "with plugin api extensions" do
      after do
        Rails.application.reload_routes!
        StaticController.custom_pages.clear
      end

      it "adds new topic-backed pages" do
        routes = Proc.new { get "contact" => "static#show", :id => "contact" }
        Discourse::Application.routes.send(:eval_block, routes)

        topic_id = Fabricate(:post, cooked: "contact info").topic_id
        SiteSetting.test_some_topic_id = topic_id

        Plugin::Instance.new.add_topic_static_page("contact", topic_id: "test_some_topic_id")

        get "/contact"

        expect(response.status).to eq(200)
        expect(response.body).to include("contact info")
      end

      it "replaces existing topic-backed pages" do
        topic_id = Fabricate(:post, cooked: "Regular FAQ").topic_id
        SiteSetting.test_some_topic_id = topic_id

        polish_topic_id = Fabricate(:post, cooked: "Polish FAQ").topic_id
        SiteSetting.test_some_other_topic_id = polish_topic_id

        Plugin::Instance
          .new
          .add_topic_static_page("faq") do
            current_user&.locale == "pl" ? "test_some_other_topic_id" : "test_some_topic_id"
          end

        get "/faq"

        expect(response.status).to eq(200)
        expect(response.body).to include("Regular FAQ")

        sign_in(Fabricate(:user, locale: "pl"))
        get "/faq"

        expect(response.status).to eq(200)
        expect(response.body).to include("Polish FAQ")
      end
    end

    it "does not pollute SiteSetting.title (regression)" do
      SiteSetting.title = "test"
      SiteSetting.short_site_description = "something"

      expect do
        get "/login"
        get "/login"
      end.to_not change { SiteSetting.title }
    end
  end

  describe "#enter" do
    context "without a redirect path" do
      it "redirects to the root url" do
        post "/login.json"
        expect(response).to redirect_to("/")
      end
    end

    context "with a redirect path" do
      it "redirects to the redirect path" do
        post "/login.json", params: { redirect: "/foo" }
        expect(response).to redirect_to("/foo")
      end
    end

    context "with a full url" do
      it "redirects to the correct path" do
        post "/login.json", params: { redirect: "#{Discourse.base_url}/foo" }
        expect(response).to redirect_to("/foo")
      end
    end

    context "with a redirect path with query params" do
      it "redirects to the redirect path and preserves query params" do
        post "/login.json", params: { redirect: "/foo?bar=1" }
        expect(response).to redirect_to("/foo?bar=1")
      end
    end

    context "with a period to force a new host" do
      it "redirects to the root path" do
        post "/login.json", params: { redirect: ".org/foo" }
        expect(response).to redirect_to("/")
      end
    end

    context "with a full url to an external host" do
      it "redirects to the root path" do
        post "/login.json", params: { redirect: "http://eviltrout.com/foo" }
        expect(response).to redirect_to("/")
      end
    end

    context "with an invalid URL" do
      it "redirects to the root" do
        post "/login.json", params: { redirect: "javascript:alert('trout')" }
        expect(response).to redirect_to("/")
      end
    end

    context "with an array" do
      it "redirects to the root" do
        post "/login.json", params: { redirect: ["/foo"] }
        expect(response.status).to eq(400)
        json = response.parsed_body
        expect(json["errors"]).to be_present
        expect(json["errors"]).to include(I18n.t("invalid_params", message: "redirect"))
      end
    end

    context "when the redirect path is the login page" do
      it "redirects to the root url" do
        post "/login.json", params: { redirect: login_path }
        expect(response).to redirect_to("/")
      end
    end

    context "when the redirect path is invalid" do
      it "redirects to the root URL" do
        post "/login.json", params: { redirect: "test" }
        expect(response).to redirect_to("/")
      end
    end
  end

  describe "#service_worker_asset" do
    it "works" do
      get "/service-worker.js"
      expect(response.status).to eq(200)
      expect(response.content_type).to start_with("application/javascript")
      expect(response.body).to include("addEventListener")
    end

    it "replaces sourcemap URL" do
      Rails
        .application
        .assets_manifest
        .stubs(:find_sources)
        .with("service-worker.js")
        .returns([<<~JS])
          someFakeServiceWorkerSource();
          //# sourceMappingURL=service-worker-abcde.js.map
        JS

      {
        "/assets/service-worker.js" => "/assets/service-worker-abcde.js.map",
        "/assets/service-worker.js.br" => "/assets/service-worker-abcde.js.map",
        "/assets/service-worker.br.js" => "/assets/service-worker-abcde.js.map",
        "/assets/service-worker.js.gz" => "/assets/service-worker-abcde.js.map",
        "/assets/service-worker.gz.js" => "/assets/service-worker-abcde.js.map",
        "https://example.com/assets/service-worker.js" =>
          "https://example.com/assets/service-worker-abcde.js.map",
        "https://example.com/subfolder/assets/service-worker.js" =>
          "https://example.com/subfolder/assets/service-worker-abcde.js.map",
      }.each do |asset_path, expected_map_url|
        ActionController::Base
          .helpers
          .stubs(:asset_path)
          .with("service-worker.js")
          .returns(asset_path)

        get "/service-worker.js"
        expect(response.status).to eq(200)
        expect(response.content_type).to start_with("application/javascript")
        expect(response.body).to include("sourceMappingURL=#{expected_map_url}\n")
      end
    end
  end
end
