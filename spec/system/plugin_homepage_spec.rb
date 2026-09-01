# frozen_string_literal: true

RSpec.describe "Plugin homepages" do
  let(:plugins) { [] }
  let(:plugin_class) do
    Class.new(Plugin::Instance) do
      attr_accessor :enabled

      def enabled?
        enabled
      end
    end
  end

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
    plugins
  end

  after do
    DiscoursePluginRegistry._raw_homepage_options.reject! do |registration|
      plugins.include?(registration[:plugin])
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

    visit "/"

    expect(page).to have_current_path("/")
    expect(page).to have_css("#plugin-public-homepage", text: "Public plugin homepage")
  end

  it "falls back for anonymous visitors but serves a private homepage to members" do
    register_homepage(
      "private-plugin",
      route: "plugin_homepage_system_spec#private_page",
      server_side: true,
    )
    select_homepage("private-plugin")

    visit "/"
    expect(page).to have_css("#list-area")
    expect(page).not_to have_css("#plugin-private-homepage")

    sign_in Fabricate(:user)
    visit "/"
    expect(page).to have_css("#plugin-private-homepage", text: "Private plugin homepage")
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

    visit "/"
    expect(page).to have_css("#plugin-alternate-homepage", text: "Alternate plugin homepage")

    selected_plugin.enabled = false
    Site.clear_cache
    visit "/"

    expect(page).to have_css("#list-area")
    expect(page).not_to have_css("#plugin-alternate-homepage")
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
    plugins << plugin
    plugin
  end

  def select_homepage(id)
    SiteSetting.default_homepage = id
    Rails.application.reload_routes!
    Site.clear_cache
  end
end
