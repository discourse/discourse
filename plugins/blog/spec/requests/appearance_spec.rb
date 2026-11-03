# frozen_string_literal: true

RSpec.describe "Blog appearance", type: :request do
  fab!(:admin)

  before { enable_blog! }

  def activate_theme(css: "", javascript: "", accent_color: "d64b2a")
    theme =
      Blog::BlogTheme.save(
        {
          "name" => "Spec design",
          "accent_color" => accent_color,
          "paper_color" => "f5f0e6",
          "ink_color" => "19382d",
          "css" => css,
          "javascript" => javascript,
        },
        user: admin,
      )
    Blog::BlogTheme.activate(theme["id"], revision: 1, user: admin)
    theme
  end

  describe "GET blog pages" do
    it "shares the configured community favicon with the blog" do
      icon = Fabricate(:upload)
      SiteSetting.favicon = icon

      get "https://blog.example.com/"

      html = Nokogiri.HTML5(response.body)
      expect(html.at_css('link[rel="icon"]')["href"]).to eq(UrlHelper.absolute(icon.url))
    end

    it "serves one built-in reader stylesheet plus the active design" do
      get "https://blog.example.com/"
      html = Nokogiri.HTML5(response.body)
      expect(response.status).to eq(200)
      expect(html.at_css("body")["data-blog-theme"]).to be_nil
      expect(html.at_css('link[href$="/blog.css"]')).to be_present
      expect(html.at_css('link[href*="blog-theme.css"]')).to be_present
      expect(html.at_css('link[href$="/editorial.css"]')).to be_nil
    end

    it "provides lazy highlighter URLs without eagerly loading the modules" do
      get "https://blog.example.com/"

      html = Nokogiri.HTML5(response.body)
      body = html.at_css("body")
      expect(body["data-blog-highlight-core-url"]).to eq(
        "https://blog.example.com#{Blog::SyntaxHighlighter.path}",
      )
      expect(body["data-blog-highlight-languages-url"]).to eq(
        "#{Discourse.base_url}#{HighlightJs.path}",
      )
      expect(body["data-blog-highlight-auto"]).to eq(SiteSetting.autohighlight_all_code.to_s)
      expect(html.css('script[src*="highlight"], link[rel="modulepreload"]')).to be_empty
    end

    it "provides translated lightbox labels to the public script" do
      get "https://blog.example.com/"

      body = Nokogiri.HTML5(response.body).at_css("body")
      expect(
        body
          .attributes
          .slice(
            *%w[
              data-blog-lightbox-close-label
              data-blog-lightbox-dialog-label
              data-blog-lightbox-open-label
              data-blog-lightbox-open-with-description-label
              data-blog-lightbox-original-label
            ],
          )
          .transform_values(&:value),
      ).to eq(
        "data-blog-lightbox-close-label" => I18n.t("blog.lightbox.close"),
        "data-blog-lightbox-dialog-label" => I18n.t("blog.lightbox.dialog"),
        "data-blog-lightbox-open-label" => I18n.t("blog.lightbox.open"),
        "data-blog-lightbox-open-with-description-label" =>
          I18n.t("blog.lightbox.open_with_description", description: "__IMAGE_DESCRIPTION__"),
        "data-blog-lightbox-original-label" => I18n.t("blog.lightbox.original"),
      )
    end

    it "keeps theme code in separate assets rather than inline HTML" do
      css = 'body::after { content: "</style><script>unsafe()</script>"; }'
      javascript = 'window.blogExample = "</script>";'
      activate_theme(css: css, javascript: javascript)

      get "https://blog.example.com/"
      html = Nokogiri.HTML5(response.body)
      expect(response.body).not_to include(css)
      expect(response.body).not_to include(javascript)
      script = html.at_css("script[data-blog-custom-script]")
      expect(script["src"]).to include("https://blog.example.com/blog-custom.js")
      expect(script["src"]).to include("blog_theme_snapshot=")
      expect(script["nonce"]).to be_present
      expect(response.headers["Content-Security-Policy"]).to include("'nonce-")
    end

    it "offers safe mode without custom CSS or JavaScript" do
      activate_theme(
        css: ".blog { display: none; }",
        javascript: 'throw new Error("broken customization");',
      )

      get "https://blog.example.com/?blog_safe_mode=1"
      html = Nokogiri.HTML5(response.body)
      expect(html.at_css("script[data-blog-custom-script]")).to be_nil
      stylesheet = html.at_css('link[href*="blog-theme.css"]')
      expect(stylesheet["href"]).to include("blog_safe_mode=1")
      get "https://blog.example.com/blog-theme.css?blog_safe_mode=1"
      expect(response.body).not_to include(".blog { display: none; }")
      expect(response.body).to include("--blog-accent-color")
      get "https://blog.example.com/blog-custom.js?blog_safe_mode=1"
      expect(response.body).to be_empty
    end
  end

  describe "GET theme assets" do
    it "serves theme code with explicit types and without caching" do
      css = ".blog__brand { letter-spacing: 0.1em; }"
      javascript = 'document.body.dataset.blogDemo = "active";'
      activate_theme(css: css, javascript: javascript)

      get "https://blog.example.com/blog-theme.css"
      expect(response.status).to eq(200)
      expect(response.media_type).to eq("text/css")
      expect(response.body).to include(css)
      expect(response.headers["Cache-Control"]).to include("no-store")

      get "https://blog.example.com/blog-custom.js"
      expect(response.status).to eq(200)
      expect(response.media_type).to eq("application/javascript")
      expect(response.body).to eq(javascript)
      expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
    end

    it "falls back to the built-in design before any theme is activated" do
      get "https://blog.example.com/blog-theme.css"
      expect(response.status).to eq(200)
      expect(response.body).to include(
        "--blog-accent-color: ##{Blog::BlogTheme::BUILT_IN_PALETTE["accent_color"]}",
      )
    end

    it "does not serve or inject blog JavaScript on the discussion origin" do
      activate_theme(javascript: 'window.blogOnly = "active";')

      get "/blog-custom.js"
      expect(response.status).to eq(404)
      expect(response.body).not_to include("window.blogOnly")
      get "/"
      expect(response.body).not_to include("/blog-custom.js")
    end
  end
end
