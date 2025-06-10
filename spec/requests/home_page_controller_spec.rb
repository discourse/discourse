# frozen_string_literal: true

RSpec.describe HomePageController do
  describe "homepage" do
    context "with crawler view" do
      before do
        SiteSetting.site_description = "This is a test description"
        SiteSetting.has_login_hint = false
      end

      it "should display the menu by default" do
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

        it "should allow plugin to override output" do
          plugin =
            plugin_class.new(nil, "#{Rails.root}/spec/fixtures/plugins/csp_extension/plugin.rb")

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

      it "should display the site description on the homepage" do
        get "/", headers: { "HTTP_USER_AGENT" => "Googlebot" }

        expect(response.status).to eq(200)
        expect(response.body).to include("<p>This is a test description</p>")
        expect(response.body).to include(
          "<meta name=\"description\" content=\"This is a test description\">",
        )
      end

      it "should not display the site description on another route" do
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
