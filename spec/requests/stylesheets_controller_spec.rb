# frozen_string_literal: true

RSpec.describe StylesheetsController do
  it "can survive cache miss" do
    StylesheetCache.destroy_all
    manager = Stylesheet::Manager.new(theme_id: nil)
    builder = Stylesheet::Manager::Builder.new(target: "desktop_rtl", manager: manager, theme: nil)
    builder.compile

    digest = StylesheetCache.first.digest
    StylesheetCache.destroy_all

    get "/stylesheets/desktop_rtl_#{digest}.css"
    expect(response.status).to eq(200)

    cached = StylesheetCache.first
    expect(cached.target).to eq "desktop_rtl"
    expect(cached.digest).to eq digest

    # tmp folder destruction and cached
    Stylesheet::Manager.rm_cache_folder

    get "/stylesheets/desktop_rtl_#{digest}.css"
    expect(response.status).to eq(200)

    # there is an edge case which is ... disk and db cache is nuked, very unlikely to happen
  end

  it "can lookup theme specific css" do
    scheme = ColorScheme.create_from_base(name: "testing", colors: [])
    theme = Fabricate(:theme, color_scheme_id: scheme.id)

    manager = Stylesheet::Manager.new(theme_id: theme.id)

    builder = Stylesheet::Manager::Builder.new(target: :desktop, theme: theme, manager: manager)
    builder.compile

    Stylesheet::Manager.rm_cache_folder

    get "/stylesheets/#{builder.stylesheet_filename.sub(".css", "")}.css"

    expect(response.status).to eq(200)

    get "/stylesheets/#{builder.stylesheet_filename_no_digest.sub(".css", "")}.css"

    expect(response.status).to eq(200)

    builder =
      Stylesheet::Manager::Builder.new(target: :desktop_theme, theme: theme, manager: manager)
    builder.compile

    Stylesheet::Manager.rm_cache_folder

    get "/stylesheets/#{builder.stylesheet_filename.sub(".css", "")}.css"

    expect(response.status).to eq(200)

    get "/stylesheets/#{builder.stylesheet_filename_no_digest.sub(".css", "")}.css"

    expect(response.status).to eq(200)
  end

  context "when there are enabled plugins" do
    fab!(:user)

    let(:plugin) do
      plugin = plugin_from_fixtures("my_plugin")
      plugin.register_css "body { padding: 1px 2px 3px 4px; }"
      plugin
    end

    before do
      Discourse.plugins << plugin
      plugin.activate!
      Stylesheet::Importer.register_imports!
      StylesheetCache.destroy_all
      SiteSetting.has_login_hint = false
      SiteSetting.allow_user_locale = true
      sign_in(user)
    end

    after do
      Discourse.plugins.delete(plugin)
      Stylesheet::Importer.register_imports!
      DiscoursePluginRegistry.reset!
    end

    it "can lookup plugin specific css" do
      get "/"

      html = Nokogiri::HTML5.fragment(response.body)
      expect(html.at("link[data-target=my_plugin_rtl]")).to eq(nil)

      href = html.at("link[data-target=my_plugin]").attribute("href").value
      get href

      expect(response.status).to eq(200)
      expect(response.headers["Content-Type"]).to eq("text/css")
      expect(response.body).to include("body{padding:1px 2px 3px 4px}")
      expect(response.body).not_to include("body{padding:1px 4px 3px 2px}")

      user.locale = "ar" # RTL locale
      user.save!
      get "/"

      html = Nokogiri::HTML5.fragment(response.body)
      expect(html.at("link[data-target=my_plugin]")).to eq(nil)

      href = html.at("link[data-target=my_plugin_rtl]").attribute("href").value
      get href

      expect(response.status).to eq(200)
      expect(response.headers["Content-Type"]).to eq("text/css")
      expect(response.body).to include("body{padding:1px 4px 3px 2px}")
      expect(response.body).not_to include("body{padding:1px 2px 3px 4px}")
    end
  end

  it "ignores Accept header and does not include Vary header" do
    StylesheetCache.destroy_all
    manager = Stylesheet::Manager.new(theme_id: nil)
    builder = Stylesheet::Manager::Builder.new(target: "desktop", manager: manager, theme: nil)
    builder.compile

    digest = StylesheetCache.first.digest

    get "/stylesheets/desktop_#{digest}.css"
    expect(response.status).to eq(200)
    expect(response.headers["Content-Type"]).to eq("text/css")
    expect(response.headers["Vary"]).to eq(nil)

    get "/stylesheets/desktop_#{digest}.css", headers: { "Accept" => "text/html" }
    expect(response.status).to eq(200)
    expect(response.headers["Content-Type"]).to eq("text/css")
    expect(response.headers["Vary"]).to eq(nil)

    get "/stylesheets/desktop_#{digest}.css", headers: { "Accept" => "invalidcontenttype" }
    expect(response.status).to eq(200)
    expect(response.headers["Content-Type"]).to eq("text/css")
    expect(response.headers["Vary"]).to eq(nil)
  end

  describe "#color_scheme" do
    it "works as expected" do
      scheme = ColorScheme.last
      get "/color-scheme-stylesheet/#{scheme.id}.json"

      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["color_scheme_id"]).to eq(scheme.id)
    end

    it "works with a theme parameter" do
      scheme = ColorScheme.last
      theme = Theme.last
      get "/color-scheme-stylesheet/#{scheme.id}/#{theme.id}.json"

      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["color_scheme_id"]).to eq(scheme.id)
    end
  end
end
