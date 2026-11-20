# frozen_string_literal: true

RSpec.describe HomePageController do
  describe "homepage" do
    context "with a registered homepage that has an availability check" do
      fab!(:user)

      let(:plugin) { Plugin::Instance.new }
      let(:allowed_user_ids) { [] }
      let(:check_calls) { [] }

      before do
        SiteSetting.has_login_hint = false
        SiteSetting.top_menu = "latest|new|top|categories"
        plugin.stubs(:enabled?).returns(true)
        plugin.register_homepage(
          "members",
          name: "plugin.members",
          path: "/members",
          route: "home_page#blank",
          available: ->(guardian:, request:) do
            check_calls << guardian.user&.id
            allowed_user_ids.include?(guardian.user&.id)
          end,
        )
        Rails.application.reload_routes!
        SiteSetting.default_homepage = "members"
        sign_in(user)
      end

      after do
        DiscoursePluginRegistry._raw_homepage_options.reject! do |registration|
          registration[:plugin] == plugin
        end
        Rails.application.reload_routes!
      end

      it "serves the registered homepage and checks availability once" do
        allowed_user_ids << user.id

        get "/"

        expect(response.status).to eq(200)
        expect(response.body).to include(
          '<meta name="discourse_current_homepage" content="members">',
        )
        expect(check_calls.size).to eq(1)
      end

      it "serves the top menu homepage when the registered one is unavailable" do
        get "/"

        expect(response.status).to eq(200)
        expect(response.body).to include(
          '<meta name="discourse_current_homepage" content="latest">',
        )
      end
    end

    context "with crawler view" do
      before do
        SiteSetting.site_description = "This is a test description"
        SiteSetting.has_login_hint = false
      end

      it "displays the menu by default" do
        get "/custom", headers: { "HTTP_USER_AGENT" => "Googlebot" }

        expect(response.status).to eq(200)
        expect(response.body).to include("<ul class=\"crawler-view-anon-menu\">")
      end

      context "with plugin override" do
        let(:plugin_class) do
          Class.new(Plugin::Instance) do
            attr_accessor :enabled

            def enabled?
              @enabled
            end
          end
        end

        it "allows a plugin to override the output" do
          plugin =
            plugin_class.new(
              nil,
              "#{Rails.root.join("spec/fixtures/plugins/csp_extension/plugin.rb")}",
            )

          plugin.register_html_builder("server:custom-homepage-crawler-view") do |c|
            "<div>override</div>"
          end
          plugin.activate!
          Discourse.plugins << plugin
          plugin.enabled = true

          get "/custom", headers: { "HTTP_USER_AGENT" => "Googlebot" }

          expect(response.status).to eq(200)
          expect(response.body).not_to include("<ul class=\"crawler-view-anon-menu\">")
          expect(response.body).to include("override")

          plugin.enabled = false
          Discourse.plugins.delete plugin
          DiscoursePluginRegistry.reset!
        end
      end

      it "displays the site description on the homepage" do
        get "/", headers: { "HTTP_USER_AGENT" => "Googlebot" }

        expect(response.status).to eq(200)
        expect(response.body).to include("<p>This is a test description</p>")
        expect(response.body).to include(
          "<meta name=\"description\" content=\"This is a test description\">",
        )
      end

      it "uses the configured crawler route when a custom homepage is enabled" do
        ThemeModifierHelper.any_instance.stubs(:custom_homepage).returns(true)
        SiteSetting.custom_homepage_crawler_route = "categories"
        category = Fabricate(:category, name: "Crawler Category")

        get "/", headers: { "HTTP_USER_AGENT" => "Googlebot" }

        expect(response.status).to eq(200)
        expect(response.body).to include(category.name)
        expect(response.body).not_to include("crawler-view-anon-menu")
      end

      it "does not display the site description on another route" do
        get "/top", headers: { "HTTP_USER_AGENT" => "Googlebot" }

        expect(response.status).to eq(200)
        expect(response.body).not_to include("<p>This is a test description</p>")
        # but still includes the meta tag
        expect(response.body).to include(
          "<meta name=\"description\" content=\"This is a test description\">",
        )
      end
    end
  end
end
