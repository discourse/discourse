# frozen_string_literal: true

RSpec.describe HomePageController do
  describe "#custom" do
    context "with crawler view" do
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
    end
  end
end
