# frozen_string_literal: true

RSpec.describe Blog::BlogThemeSerializer do
  subject(:json) { described_class.new(theme, root: false).as_json.deep_stringify_keys }

  fab!(:admin)

  let(:draft) do
    create_blog_theme(
      Blog::BlogTheme.defaults.merge("name" => "Quiet draft", "template_index" => "<h1>Hi</h1>"),
      user: admin,
    )
  end
  let(:theme) { draft }

  before { enable_blog! }

  it "presents the stored draft with a preview link" do
    expect(json.except("preview_url", "preset")).to eq(theme)
    expect(json["preset"]).to eq(false)
    expect(json).not_to include("description", "screenshot_light_url", "screenshot_dark_url")
    expect(json["preview_url"]).to start_with("https://blog.example.com/?blog_theme_preview=")
  end

  it "links to a preview of the serialized revision" do
    token = Rack::Utils.parse_query(URI(json["preview_url"]).query)["blog_theme_preview"]
    expect(Blog::ThemePreview.theme_for(token)).to eq(draft)
  end

  context "with an activated copy" do
    let(:theme) { activate_blog_theme(draft, user: admin) }

    it "includes the snapshot id" do
      expect(json.except("preview_url", "preset")).to eq(theme)
    end
  end

  context "with a preset" do
    let(:theme) { Blog::ThemePresets.find("discourse-blog") }

    it "marks it as a preset with a description and a working preview link" do
      expect(json["preset"]).to eq(true)
      expect(json["description"]).to eq(theme["description"])
      expect(json["screenshot_light_url"]).to eq(theme["screenshot_light_url"])
      expect(json["screenshot_dark_url"]).to eq(theme["screenshot_dark_url"])
      token = Rack::Utils.parse_query(URI(json["preview_url"]).query)["blog_theme_preview"]
      expect(Blog::ThemePreview.theme_for(token)).to eq(theme)
    end
  end
end
