# frozen_string_literal: true

RSpec.describe "Plugin homepages" do
  before do
    Object.const_set(
      :PluginHomepageSystemSpecController,
      Class.new(ApplicationController) do
        layout "no_ember"
        skip_before_action :check_xhr, :preload_json

        def public_page
          render html: '<main id="plugin-public-homepage">Public plugin homepage</main>'.html_safe
        end

        def private_page
          render html: '<main id="plugin-private-homepage">Private plugin homepage</main>'.html_safe
        end

        def alternate_page
          render html:
                   '<main id="plugin-alternate-homepage">Alternate plugin homepage</main>'.html_safe
        end
      end,
    )
    @plugins = []
  end

  after do
    DiscoursePluginRegistry._raw_homepage_options.reject! do |registration|
      @plugins.include?(registration[:plugin])
    end
    Rails.application.reload_routes!
    Site.clear_cache
    Object.send(:remove_const, :PluginHomepageSystemSpecController)
  end

  it "serves an anonymous plugin homepage directly at the root" do
    register_homepage(
      "public-plugin",
      route: "plugin_homepage_system_spec#public_page",
      anonymous: true,
      server_side: true,
    )
    select_homepage("public-plugin")

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(browser_page).to have_url("/")
    expect(browser_root.locator("#plugin-public-homepage").filter(visible: true)).to contain_text(
      [browser_text_pattern("Public plugin homepage")],
      useInnerText: true,
    )
  end

  it "falls back for anonymous visitors but serves a private homepage to members" do
    register_homepage(
      "private-plugin",
      route: "plugin_homepage_system_spec#private_page",
      server_side: true,
    )
    select_homepage("private-plugin")

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("#list-area")).not_to have_count(0)
    expect(browser_root.locator("#list-area")).not_to have_css("display", "none")
    expect(browser_root.locator("#list-area")).to have_css("visibility", "visible")
    expect(browser_root.locator("#plugin-private-homepage").filter(visible: true)).to have_count(0)

    sign_in Fabricate(:user)
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("#plugin-private-homepage").filter(visible: true)).to contain_text(
      [browser_text_pattern("Private plugin homepage")],
      useInnerText: true,
    )
  end

  it "supports multiple registrations and falls back when the selected plugin is disabled" do
    register_homepage(
      "sample-homepage",
      route: "plugin_homepage_system_spec#public_page",
      anonymous: true,
      server_side: true,
    )
    selected_plugin =
      register_homepage(
        "sample_homepage",
        route: "plugin_homepage_system_spec#alternate_page",
        anonymous: true,
        server_side: true,
      )
    select_homepage("sample_homepage")

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator("#plugin-alternate-homepage").filter(visible: true),
    ).to contain_text([browser_text_pattern("Alternate plugin homepage")], useInnerText: true)

    selected_plugin.enabled = false
    Site.clear_cache
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(browser_root.locator("#list-area")).not_to have_count(0)
    expect(browser_root.locator("#list-area")).not_to have_css("display", "none")
    expect(browser_root.locator("#list-area")).to have_css("visibility", "visible")
    expect(browser_root.locator("#plugin-alternate-homepage").filter(visible: true)).to have_count(
      0,
    )
  end

  private

  def register_homepage(id, route:, anonymous: false, server_side: false)
    plugin = plugin_class.new
    plugin.enabled = true
    plugin.register_homepage(
      id,
      name: "plugin.#{id}",
      path: "/#{id}",
      route:,
      anonymous:,
      server_side:,
    )
    @plugins << plugin
    plugin
  end

  def select_homepage(id)
    SiteSetting.default_homepage = id
    Rails.application.reload_routes!
    Site.clear_cache
  end

  def plugin_class
    @plugin_class ||=
      Class.new(Plugin::Instance) do
        attr_accessor :enabled

        def enabled?
          enabled
        end
      end
  end
end
