# frozen_string_literal: true

describe "Content security policy" do
  let(:plugin_class) do
    Class.new(Plugin::Instance) do
      attr_accessor :enabled

      def enabled?
        @enabled
      end
    end
  end

  it "can boot the application in strict_dynamic mode even with invalid directives from CSP extensions" do
    plugin =
      plugin_class.new(nil, "#{Rails.root.join("spec/fixtures/plugins/csp_extension/plugin.rb")}")

    plugin.activate!
    Discourse.plugins << plugin

    plugin.enabled = true

    expect(SiteSetting.content_security_policy).to eq(true)
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("#site-logo").filter(visible: true)).not_to have_count(0)

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

    browser_page.goto("/nonexistent").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("#site-logo").filter(visible: true)).not_to have_count(0)
    expect(browser_root.locator("body.no-ember").filter(visible: true)).to have_count(0)
  end

  it "can boot logster in strict_dynamic mode" do
    expect(SiteSetting.content_security_policy).to eq(true)
    sign_in Fabricate(:admin)

    browser_page.goto("/logs").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("#log-table")).not_to have_count(0)
    expect(browser_root.locator("#log-table")).not_to have_css("display", "none")
    expect(browser_root.locator("#log-table")).to have_css("visibility", "visible")
  end
end
