# frozen_string_literal: true

describe "Content security policy", type: :system do
  let(:plugin_class) do
    Class.new(Plugin::Instance) do
      attr_accessor :enabled

      def enabled?
        @enabled
      end
    end
  end

  it "can boot the application in strict_dynamic mode even with invalid directives from CSP extensions" do
    plugin = plugin_class.new(nil, "#{Rails.root}/spec/fixtures/plugins/csp_extension/plugin.rb")

    plugin.activate!
    Discourse.plugins << plugin

    plugin.enabled = true

    expect(SiteSetting.content_security_policy).to eq(true)
    visit "/"
    expect(page).to have_css("#site-logo")

    get "/"
    expect(response.headers["Content-Security-Policy"]).to include("'strict-dynamic'")
    expect(response.headers["Content-Security-Policy"]).not_to include(
      "'unsafe-eval' https://invalid.example.com'",
    )

    Discourse.plugins.delete plugin
    DiscoursePluginRegistry.reset!
  end

  it "works for 'public exceptions' like RoutingError" do
    expect(SiteSetting.content_security_policy).to eq(true)
    SiteSetting.bootstrap_error_pages = true

    get "/nonexistent"
    expect(response.headers["Content-Security-Policy"]).to include("'strict-dynamic'")

    visit "/nonexistent"
    expect(page).not_to have_css("body.no-ember")
    expect(page).to have_css("#site-logo")
  end

  it "can boot logster in strict_dynamic mode" do
    expect(SiteSetting.content_security_policy).to eq(true)
    sign_in Fabricate(:admin)

    visit "/logs"
    expect(page).to have_css("#log-table")
  end
end
