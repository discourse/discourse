# frozen_string_literal: true

RSpec.describe Blog::BlogHelper, type: :helper do
  include_context "with a public blog"

  describe "#blog_url" do
    it "builds a URL on the blog" do
      expect(helper.blog_url("/about")).to eq("https://blog.example.com/about")
    end

    it "keeps a theme preview across links" do
      assign(:theme_preview_token, "preview-token")

      expect(helper.blog_url("/about")).to eq(
        "https://blog.example.com/about?blog_theme_preview=preview-token",
      )
      expect(helper.blog_url("/archive?page=2")).to eq(
        "https://blog.example.com/archive?page=2&blog_theme_preview=preview-token",
      )
    end
  end

  describe "#blog_theme" do
    it "defaults to the active theme" do
      expect(helper.blog_theme).to eq(Blog::BlogTheme.active)
    end
  end

  describe "#blog_customizations_disabled?" do
    it "is true only in safe mode" do
      expect(helper).not_to be_blog_customizations_disabled

      controller.params[:blog_safe_mode] = "1"

      expect(helper).to be_blog_customizations_disabled
    end
  end

  describe "#blog_theme_asset_url" do
    it "links the theme stylesheet" do
      expect(helper.blog_theme_asset_url).to eq("https://blog.example.com/blog-theme.css")
    end

    it "pins the theme snapshot and safe mode" do
      assign(:blog_theme, { "snapshot" => "snapshot-id" })
      controller.params[:blog_safe_mode] = "1"

      expect(helper.blog_theme_asset_url("/blog-custom.js")).to eq(
        "https://blog.example.com/blog-custom.js?blog_safe_mode=1&blog_theme_snapshot=snapshot-id",
      )
    end

    it "serves a previewed theme instead of the snapshot" do
      assign(:blog_theme, { "snapshot" => "snapshot-id" })
      assign(:theme_preview_token, "preview-token")

      expect(helper.blog_theme_asset_url).to eq(
        "https://blog.example.com/blog-theme.css?blog_theme_preview=preview-token",
      )
    end
  end

  describe "#blog_render_template" do
    before do
      assign(:template_variables, Blog::TemplateVariables.new)
      assign(
        :blog_theme,
        Blog::BlogTheme.defaults.merge(
          "template_about" => "<p class=\"custom\">{{ site.title }}</p>",
          "template_layout" => "<main>{{ content_html }}</main>",
        ),
      )
    end

    it "renders the theme's template" do
      output = helper.blog_render_template("about")

      expect(output).to be_html_safe
      expect(output).to eq("<p class=\"custom\">#{SiteSetting.blog_title}</p>")
    end

    it "wraps page content in the layout" do
      expect(helper.blog_render_template("layout", content: "<p>Page</p>")).to eq(
        "<main><p>Page</p></main>",
      )
    end

    it "uses the built-in template for article previews and in safe mode" do
      assign(:preview, true)
      expect(helper.blog_render_template("about")).not_to include("class=\"custom\"")

      assign(:preview, false)
      controller.params[:blog_safe_mode] = "1"
      expect(helper.blog_render_template("about")).not_to include("class=\"custom\"")
    end

    it "reports template problems while previewing a theme" do
      assign(:blog_theme, Blog::BlogTheme.defaults.merge("template_about" => "{{ missing }}"))
      assign(:theme_preview_token, "preview-token")

      expect(helper.blog_render_template("about")).to include("data-template-diagnostic")
    end
  end
end
