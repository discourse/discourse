# frozen_string_literal: true

RSpec.describe "Blog themes", type: :request do
  fab!(:admin)
  fab!(:moderator)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:first_post) { Fabricate(:post, topic: topic) }

  let(:attributes) do
    {
      name: "Quiet draft",
      accent_color: "112233",
      paper_color: "fafafa",
      ink_color: "222222",
      css: ".blog { letter-spacing: 0.1px; }",
      javascript: 'document.body.dataset.themePreview = "yes";',
    }
  end

  before do
    enable_blog!(category: category)
    https!
  end

  it "previews custom templates, freezes activation, and retains the safe-mode escape hatch" do
    get "https://test.localhost/session/#{admin.encoded_username}/become"
    custom =
      attributes.merge(
        template_index: "<h1 data-custom-liquid>{{ site.title }}</h1>",
        template_layout: "<div data-custom-layout>{{ content_html }}</div>",
      )
    post "https://test.localhost/blog/themes.json", params: { theme: custom }
    expect(response.status).to eq(201)
    draft = response.parsed_body
    get "https://blog.example.com/"
    expect(response.body).not_to include("data-custom-liquid")
    get draft["preview_url"]
    expect(response.body).to include("data-custom-liquid", "data-custom-layout")
    expect(response.headers["Cache-Control"]).to include("no-store")
    post "https://test.localhost/blog/themes/#{draft["id"]}/activate.json", params: { revision: 1 }
    expect(response.status).to eq(200)
    put "https://test.localhost/blog/themes/#{draft["id"]}.json",
        params: {
          theme: custom.merge(template_index: "Changed draft only"),
          revision: 1,
        }
    expect(response.status).to eq(200)
    get "https://blog.example.com/"
    expect(response.body).to include("data-custom-liquid")
    expect(response.body).not_to include("Changed draft only")
    get "https://blog.example.com/", params: { blog_safe_mode: 1 }
    expect(response.body).not_to include("data-custom-liquid", "data-custom-layout")
    expect(response.body).to include('class="blog__header"')
  end

  it "keeps authenticated editorial previews and feeds independent of custom templates" do
    drafts = Fabricate(:private_category, group: Group[:staff])
    SiteSetting.blog_drafts_category = drafts.id
    private_topic = Fabricate(:topic, category: drafts, user: admin)
    private_post = Fabricate(:post, topic: private_topic, user: admin)
    theme =
      Blog::BlogTheme.save(
        attributes.stringify_keys.merge(
          "template_article" => "CUSTOM ARTICLE",
          "template_layout" => "CUSTOM LAYOUT",
        ),
        user: admin,
      )
    Blog::BlogTheme.activate(theme["id"], revision: 1, user: admin)
    get "https://test.localhost/session/#{admin.encoded_username}/become"
    get "https://test.localhost/blog/preview/#{private_topic.id}"
    expect(response.status).to eq(200)
    expect(response.body).to include(private_post.cooked)
    expect(response.body).not_to include("CUSTOM ARTICLE", "CUSTOM LAYOUT")
    get "https://blog.example.com/feed.xml"
    expect(response.status).to eq(200)
    expect(Nokogiri.XML(response.body).at_xpath("/rss/channel")).to be_present
  end

  it "exposes only public frozen articles to a custom listing template" do
    publication =
      Blog::Publication.create!(
        topic: topic,
        discussion_topic: topic,
        published: true,
        published_at: 1.day.ago,
        path: "/public-story",
      )
    private_category = Fabricate(:private_category, group: Group[:staff])
    private_topic =
      Fabricate(
        :topic,
        category: private_category,
        user: admin,
        title: "Private draft title not for readers",
      )
    Fabricate(:post, topic: private_topic, user: admin)
    theme =
      Blog::BlogTheme.save(
        attributes.stringify_keys.merge(
          "template_index" =>
            "{% for article in articles %}<h2>{{ article.title }}</h2>{{ article.raw }}{{ article.source_topic_id }}{% endfor %}",
        ),
        user: admin,
      )
    Blog::BlogTheme.activate(theme["id"], revision: 1, user: admin)
    get "https://blog.example.com/"
    expect(response.status).to eq(200)
    expect(response.body).to include(publication.published_revision.title)
    expect(response.body).not_to include(private_topic.title, first_post.raw)
  end

  describe "Discourse Blog reference theme" do
    let(:reference_theme) do
      root = Rails.root.join("plugins/blog/branding/discourse-blog")
      values =
        JSON.parse(File.read(root.join("blog-theme.json"))).merge(
          "css" => File.read(root.join("blog.css")),
          "javascript" => "",
        )
      Blog::TemplateRenderer::PAGES.each do |page|
        values["template_#{page}"] = File.read(root.join("templates/#{page}.liquid"))
      end
      Blog::BlogTheme.save(values, user: admin)
    end

    it "previews each page with the local identity and preserves the discussion and live theme" do
      publication =
        Blog::Publication.create!(
          topic: topic,
          discussion_topic: topic,
          published: true,
          published_at: 1.day.ago,
          path: "/reference-story",
        )
      Blog::Path.create!(publication: publication, path: publication.path)
      active = Blog::BlogTheme.active
      token = Blog::BlogTheme.preview_token(reference_theme)

      {
        "/" => 200,
        "/archive" => 200,
        publication.path => 200,
        "/about" => 200,
        "/missing-reference-page" => 404,
      }.each do |path, status|
        get "https://blog.example.com#{path}", params: { blog_theme_preview: token }
        expect(response.status).to eq(status)
        document = Nokogiri.HTML5(response.body)
        expect(document.css(".discourse-journal #main").size).to eq(1)
        expect(document.at_css(".discourse-journal__brand").text).to include(SiteSetting.blog_title)
        expect(document.css("[data-template-diagnostic]")).to be_empty
        if path == publication.path
          expect(document.css("#discussion").size).to eq(1)
          expect(document.at_css(".blog-article__body").inner_html).to include(first_post.cooked)
        end
      end
      expect(Blog::BlogTheme.active).to eq(active)
    end

    it "renders an empty listing and carries the preview through archive searches" do
      token = Blog::BlogTheme.preview_token(reference_theme)
      get "https://blog.example.com/archive",
          params: {
            blog_theme_preview: token,
            q: "No matching article",
          }

      expect(response.status).to eq(200)
      document = Nokogiri.HTML5(response.body)
      expect(document.at_css(".discourse-journal__empty").text).to include(
        I18n.t("blog.empty_title"),
      )
      expect(document.at_css('input[name="blog_theme_preview"]')["value"]).to eq(token)
      expect(document.at_css('input[name="q"]')["value"]).to eq("No matching article")
      expect(document.css("[data-template-diagnostic]")).to be_empty
    end
  end

  describe "management" do
    it "requires administrators and rejects the public blog origin" do
      get "https://test.localhost/blog/themes.json"
      expect(response.status).to eq(403)
      get "https://test.localhost/session/#{moderator.encoded_username}/become"
      get "https://test.localhost/blog/themes.json"
      expect(response.status).to eq(403)
      post "https://test.localhost/blog/themes.json", params: { theme: attributes }
      expect(response.status).to eq(403)
      expect(Blog::BlogTheme.all).to be_empty
      get "https://test.localhost/session/#{admin.encoded_username}/become"
      get "https://test.localhost/blog/themes.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["themes"]).to be_empty
      get "https://blog.example.com/blog/themes.json"
      expect(response.status).to eq(404)
    end

    it "serves focused theme data and supports direct loading of all admin pages" do
      get "https://test.localhost/session/#{admin.encoded_username}/become"
      post "https://test.localhost/blog/themes.json", params: { theme: attributes }
      draft = response.parsed_body
      get "https://test.localhost/blog/themes/#{draft["id"]}.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("theme", "id")).to eq(draft["id"])
      expect(response.parsed_body.dig("theme", "css")).to eq(attributes[:css])
      expect(response.parsed_body.dig("theme", "preview_url")).to be_present
      %W[
        themes
        themes/new
        themes/import/new
        themes/#{draft["id"]}/edit
        identity
        appearance
      ].each do |path|
        get "https://test.localhost/admin/plugins/blog/#{path}"
        expect(response.status).to eq(200)
      end
      get "https://test.localhost/blog/themes/missing.json"
      expect(response.status).to eq(404)
      get "https://test.localhost/session/#{moderator.encoded_username}/become"
      get "https://test.localhost/blog/themes/#{draft["id"]}.json"
      expect(response.status).to eq(403)
    end

    it "saves multiple drafts without changing readers, then explicitly activates a snapshot" do
      get "https://test.localhost/session/#{admin.encoded_username}/become"
      post "https://test.localhost/blog/themes.json", params: { theme: attributes }
      expect(response.status).to eq(201)
      draft = response.parsed_body
      expect(draft["preview_url"]).to start_with("https://blog.example.com/?blog_theme_preview=")
      get "https://blog.example.com/blog-theme.css"
      expect(response.body).not_to include(attributes[:css])
      get "https://blog.example.com/"
      expect(Nokogiri.HTML5(response.body).at_css('link[href*="blog-theme.css"]')).to be_present

      post "https://test.localhost/blog/themes/#{draft["id"]}/activate.json",
           params: {
             revision: draft["revision"],
           }
      expect(response.status).to eq(200)
      get "https://blog.example.com/"
      html = Nokogiri.HTML5(response.body)
      css_url = html.at_css('link[href*="blog-theme.css"]')["href"]
      js_url = html.at_css("script[data-blog-custom-script]")["src"]

      changed =
        attributes.merge(css: ".blog { font-size: 42px; }", javascript: "window.changed = true;")
      put "https://test.localhost/blog/themes/#{draft["id"]}.json",
          params: {
            theme: changed,
            revision: 1,
          }
      expect(response.status).to eq(200)
      expect(response.parsed_body["revision"]).to eq(2)
      get "https://blog.example.com/blog-theme.css"
      expect(response.body).to include(attributes[:css])
      expect(response.body).not_to include(changed[:css])

      post "https://test.localhost/blog/themes/#{draft["id"]}/activate.json",
           params: {
             revision: 2,
           }
      get "https://blog.example.com/blog-theme.css"
      expect(response.body).to include(changed[:css])
      get css_url
      expect(response.body).to include(attributes[:css])
      get js_url
      expect(response.body).to eq(attributes[:javascript])
      expect(
        UserHistory.where(acting_user_id: admin.id, custom_type: "blog_theme_activate").count,
      ).to eq(2)

      post "https://test.localhost/blog/themes.json",
           params: {
             theme: attributes.merge(name: "Another design"),
           }
      expect(response.status).to eq(201)
      get "https://test.localhost/blog/themes.json"
      expect(response.parsed_body["themes"].map { |theme| theme["name"] }).to contain_exactly(
        "Quiet draft",
        "Another design",
      )
      expect(response.parsed_body["active"]["revision"]).to eq(2)
    end

    it "rejects stale changes and activation, and protects the active theme from deletion" do
      get "https://test.localhost/session/#{admin.encoded_username}/become"
      post "https://test.localhost/blog/themes.json", params: { theme: attributes }
      draft = response.parsed_body
      put "https://test.localhost/blog/themes/#{draft["id"]}.json",
          params: {
            theme: attributes.merge(name: "Updated"),
            revision: 1,
          }
      put "https://test.localhost/blog/themes/#{draft["id"]}.json",
          params: {
            theme: attributes,
            revision: 1,
          }
      expect(response.status).to eq(400)
      post "https://test.localhost/blog/themes/#{draft["id"]}/activate.json",
           params: {
             revision: 1,
           }
      expect(response.status).to eq(400)
      delete "https://test.localhost/blog/themes/#{draft["id"]}.json", params: { revision: 1 }
      expect(response.status).to eq(400)
      post "https://test.localhost/blog/themes/#{draft["id"]}/activate.json",
           params: {
             revision: 2,
           }
      expect(response.status).to eq(200)
      delete "https://test.localhost/blog/themes/#{draft["id"]}.json", params: { revision: 2 }
      expect(response.status).to eq(400)
      expect(Blog::BlogTheme.find(draft["id"])["name"]).to eq("Updated")
    end

    it "validates bounded theme content and permits deleting unused drafts" do
      get "https://test.localhost/session/#{admin.encoded_username}/become"
      [
        { name: "" },
        { accent_color: "red; }" },
        { css: "a" * 65_537 },
        { javascript: "ü" * 32_769 },
      ].each do |invalid|
        post "https://test.localhost/blog/themes.json", params: { theme: attributes.merge(invalid) }
        expect(response.status).to eq(400)
      end
      expect(Blog::BlogTheme.all).to be_empty
      post "https://test.localhost/blog/themes.json", params: { theme: attributes }
      draft = response.parsed_body
      delete "https://test.localhost/blog/themes/#{draft["id"]}.json", params: { revision: 1 }
      expect(response.status).to eq(204)
      get draft["preview_url"]
      expect(response.status).to eq(404)
    end
  end

  describe "ZIP endpoints" do
    it "exports the saved draft and imports the download as a new inactive draft" do
      get "https://test.localhost/session/#{admin.encoded_username}/become"
      theme = Blog::BlogTheme.save(attributes.stringify_keys, user: admin)

      get "https://test.localhost/blog/themes/#{theme["id"]}/export"

      expect(response.status).to eq(200)
      expect(response.media_type).to eq("application/zip")
      expect(response.headers["Content-Disposition"]).to include(
        "attachment",
        "blog-theme-quiet-draft.zip",
      )
      Tempfile.create(%w[blog-theme .zip]) do |file|
        file.binmode
        file.write(response.body)
        file.flush
        post "https://test.localhost/blog/themes/import.json",
             params: {
               file: Rack::Test::UploadedFile.new(file.path, "application/zip"),
             }
      end

      expect(response.status).to eq(201)
      expect(response.parsed_body["name"]).to eq(theme["name"])
      expect(response.parsed_body["id"]).not_to eq(theme["id"])
      expect(response.parsed_body["source"]).to be_nil
      expect(Blog::BlogTheme.active["id"]).to be_nil
    end

    it "restricts imports and exports to admins on the discussion host" do
      theme = Blog::BlogTheme.save(attributes.stringify_keys, user: admin)
      get "https://test.localhost/blog/themes/#{theme["id"]}/export"
      expect(response.status).to eq(403)
      post "https://test.localhost/blog/themes/import.json", params: { file: "theme.zip" }
      expect(response.status).to eq(403)

      get "https://test.localhost/session/#{moderator.encoded_username}/become"
      get "https://test.localhost/blog/themes/#{theme["id"]}/export"
      expect(response.status).to eq(403)
      post "https://test.localhost/blog/themes/import.json", params: { file: "theme.zip" }
      expect(response.status).to eq(403)

      get "https://test.localhost/session/#{admin.encoded_username}/become"
      get "https://blog.example.com/blog/themes/#{theme["id"]}/export"
      expect(response.status).to eq(404)
      get "https://test.localhost/blog/themes/missing/export"
      expect(response.status).to eq(404)
      post "https://test.localhost/blog/themes/import.json", params: { file: "theme.zip" }
      expect(response.status).to eq(400)
    end
  end

  describe "Git endpoints" do
    it "imports and pulls the configured source without activating it" do
      Dir.mktmpdir do |directory|
        File.write(
          File.join(directory, "blog-theme.json"),
          attributes.except(:css, :javascript).merge(version: 1).to_json,
        )
        File.write(File.join(directory, "blog.css"), attributes[:css])
        importer = ThemeStore::DirectoryImporter.new(directory)
        importer.stubs(:version).returns("a" * 40)
        Blog::ThemeImporter::GitSource.stubs(:new).returns(importer)
        get "https://test.localhost/session/#{admin.encoded_username}/become"
        post "https://test.localhost/blog/themes/import.json",
             params: {
               repository: "https://github.com/example/theme",
               branch: "design",
             }
        expect(response.status).to eq(201)
        draft = response.parsed_body
        expect(draft.dig("source", "branch")).to eq("design")
        File.write(File.join(directory, "blog.css"), ".blog { color: blue; }")
        post "https://test.localhost/blog/themes/#{draft["id"]}/pull.json", params: { revision: 1 }
        expect(response.status).to eq(200)
        expect(response.parsed_body["revision"]).to eq(2)
        expect(response.parsed_body["css"]).to eq(".blog { color: blue; }")
        get "https://blog.example.com/blog-theme.css"
        expect(response.body).not_to include(attributes[:css], ".blog { color: blue; }")
        expect(File.exist?(importer.temp_folder)).to eq(false)
      end
    end
  end

  describe "preview" do
    it "previews only public content and carries the capability through navigation and assets" do
      publication =
        Blog::Publication.create!(
          topic: topic,
          path: "/a-story",
          published: true,
          published_at: 1.day.ago,
        )
      publication.paths.create!(path: publication.path)
      get "https://test.localhost/session/#{admin.encoded_username}/become"
      post "https://test.localhost/blog/themes.json", params: { theme: attributes }
      draft = response.parsed_body
      get draft["preview_url"]
      expect(response.status).to eq(200)
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(response.headers["X-Robots-Tag"]).to include("noindex")
      expect(response.headers["Referrer-Policy"]).to eq("no-referrer")
      html = Nokogiri.HTML5(response.body)
      expect(html.at_css("body")["data-blog-theme"]).to be_nil
      expect(html.at_css('link[href$="/editorial.css"]')).to be_nil
      expect(html.at_css(".blog__preview").text).to include(attributes[:name])
      expect(html.at_css('link[rel="canonical"]')).to be_nil
      expect(html.at_css(".blog-card h2 a")["href"]).to include(
        "#{publication.path}?blog_theme_preview=",
      )
      expect(html.at_css(".blog__nav a")["href"]).to include("blog_theme_preview=")
      get html.at_css('link[href*="blog-theme.css"]')["href"]
      expect(response.body).to include(attributes[:css], "#112233")
      get html.at_css("script[data-blog-custom-script]")["src"]
      expect(response.body).to eq(attributes[:javascript])
      get "https://blog.example.com/blog-custom.js"
      expect(response.body).not_to include(attributes[:javascript])
      get "https://test.localhost/blog-custom.js",
          params: {
            blog_theme_preview:
              URI.decode_www_form(URI(draft["preview_url"]).query).to_h["blog_theme_preview"],
          }
      expect(response.status).to eq(404)
      get "#{draft["preview_url"]}&blog_safe_mode=1"
      expect(Nokogiri.HTML5(response.body).at_css("script[data-blog-custom-script]")).to be_nil

      get html.at_css(".blog-card h2 a")["href"]
      expect(response.status).to eq(200)
      get html.at_css(".blog__nav a")["href"]
      expect(
        Nokogiri.HTML5(response.body).at_css('input[name="blog_theme_preview"]')["value"],
      ).to be_present

      topic.update!(category: Fabricate(:private_category, group: Group[:staff]))
      get html.at_css(".blog-card h2 a")["href"]
      expect(response.status).to eq(404)
    end

    it "rejects tampered, expired, and superseded preview links" do
      get "https://test.localhost/session/#{admin.encoded_username}/become"
      post "https://test.localhost/blog/themes.json", params: { theme: attributes }
      draft = response.parsed_body
      get "#{draft["preview_url"]}tampered"
      expect(response.status).to eq(404)
      freeze_time 61.minutes.from_now
      get draft["preview_url"]
      expect(response.status).to eq(404)
      get "https://test.localhost/blog/themes.json"
      url = response.parsed_body["themes"].first["preview_url"]
      get url
      expect(response.status).to eq(200)
      put "https://test.localhost/blog/themes/#{draft["id"]}.json",
          params: {
            theme: attributes,
            revision: 1,
          }
      get url
      expect(response.status).to eq(404)
    end
  end
end
