# frozen_string_literal: true

RSpec.describe Blog::BlogHelper, type: :helper do
  include_context "with a public blog"

  fab!(:tag) { Fabricate(:tag, name: "field-notes") }
  fab!(:hidden_tag) { Fabricate(:tag, name: "staff-notes") }
  fab!(:tag_group) do
    Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
  end
  fab!(:publication) do
    publish_blog_article(
      Fabricate(:topic, category: blog_category, tags: [tag]),
      path: "/field-story",
      excerpt: "A standfirst",
      published_at: 3.days.ago,
    )
  end

  let(:article) { publication.article }

  def revision_with(data)
    Blog::Revision.new(data:)
  end

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

  describe "#blog_article_html" do
    before { set_cdn_url("https://cdn.example.com") }

    it "makes root-relative links and media absolute" do
      html = helper.blog_article_html(revision_with("cooked" => <<~HTML))
        <a href="/t/topic/1">Topic</a>
        <a href="#footnote">Footnote</a>
        <a href="//elsewhere.example.com/page">Elsewhere</a>
        <img src="/uploads/image.png" srcset="/uploads/image.png 1x, /uploads/image@2x.png 2x">
        <video poster="/uploads/poster.png"></video>
        <div class="spoiler">Hidden</div>
      HTML
      document = Nokogiri::HTML5.fragment(html)

      expect(html).to be_html_safe
      expect(document.css("a").map { |link| link["href"] }).to eq(
        %w[http://test.localhost/t/topic/1 #footnote //elsewhere.example.com/page],
      )
      expect(document.at_css("img")["src"]).to eq("https://cdn.example.com/uploads/image.png")
      expect(document.at_css("img")["srcset"]).to eq(
        "https://cdn.example.com/uploads/image.png 1x, https://cdn.example.com/uploads/image@2x.png 2x",
      )
      expect(document.at_css("video")["poster"]).to eq("https://cdn.example.com/uploads/poster.png")
      expect(document.at_css(".spoiler")["tabindex"]).to eq("0")
    end

    it "renders nothing without a post" do
      expect(helper.blog_article_html(nil)).to eq("")
    end
  end

  describe "#blog_date" do
    it "formats the date, defaulting to today" do
      freeze_time(Time.zone.parse("2026-03-04 10:00"))

      expect(helper.blog_date(Time.zone.parse("2025-12-25 08:00"))).to eq("December 25, 2025")
      expect(helper.blog_date(nil)).to eq("March 4, 2026")
    end
  end

  describe "#blog_revision_tags" do
    it "returns only tags everyone can see" do
      revision = revision_with("tags" => [tag.name, hidden_tag.name, "missing-tag"])

      expect(helper.blog_revision_tags(revision)).to contain_exactly(tag)
    end
  end

  describe "#blog_revision_image" do
    it "returns the absolute image URL when the revision has one" do
      expect(helper.blog_revision_image(nil)).to be_nil
      expect(helper.blog_revision_image(revision_with("image_url" => ""))).to be_nil
      expect(helper.blog_revision_image(revision_with("image_url" => "/uploads/cover.png"))).to eq(
        "http://test.localhost/uploads/cover.png",
      )
    end
  end

  describe "#blog_page_url" do
    before { controller.request.path = "/archive" }

    it "links to a page of the current listing, keeping the search" do
      expect(helper.blog_page_url(2)).to eq("https://blog.example.com/archive?page=2")

      assign(:query, "needle")

      expect(helper.blog_page_url(3)).to eq("https://blog.example.com/archive?page=3&q=needle")
    end
  end

  describe "#blog_render_template" do
    before do
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

  describe "#blog_template_assigns" do
    it "describes the site and an unfiltered listing" do
      SiteSetting.blog_about = "We publish **field notes**."
      assign(:publications, [publication])

      assigns = helper.blog_template_assigns

      expect(assigns["site"]).to include(
        "title" => SiteSetting.blog_title,
        "url" => "https://blog.example.com/",
        "archive_url" => "https://blog.example.com/archive",
        "feed_url" => "https://blog.example.com/feed.xml",
        "editor_url" => "#{Discourse.base_url}/blog-editor",
      )
      expect(assigns["site"]["about_html"]).to include("<strong>field notes</strong>")
      expect(assigns["page"]).to include(
        "heading" => SiteSetting.blog_title,
        "eyebrow" => I18n.t("blog.from_the_blog"),
        "archive" => false,
        "previous_url" => nil,
        "next_url" => nil,
      )
      expect(assigns["labels"]).to include("archive" => I18n.t("blog.archive"))
      expect(assigns["articles"].map { |values| values["url"] }).to eq([publication.url])
      expect(assigns["article"]).to be_nil
    end

    it "links neighbouring archive pages" do
      controller.request.path = "/archive"
      assign(:archive, true)
      assign(:page, 2)
      assign(:more, true)

      expect(helper.blog_template_assigns["page"]).to include(
        "heading" => I18n.t("blog.archive"),
        "archive" => true,
        "previous_url" => "https://blog.example.com/archive?page=1",
        "next_url" => "https://blog.example.com/archive?page=3",
      )
    end

    it "names the tag on tag pages" do
      assign(:tag, tag)

      expect(helper.blog_template_assigns["page"]).to include(
        "heading" => tag.name,
        "eyebrow" => I18n.t("blog.tagged", tag: tag.name),
      )
    end

    it "includes the full article on article pages" do
      assign(:publication, publication)
      assign(:article, article)
      assign(:topic, publication.discussion_topic)

      expect(helper.blog_template_assigns["article"]).to include(
        "url" => publication.url,
        "body_html" => be_present,
      )
    end
  end

  describe "#blog_authoring_template_assigns" do
    it "offers a placeholder article until one is chosen" do
      expect(helper.blog_authoring_template_assigns["article"]).to include(
        "title" => I18n.t("blog.themes.sample_article"),
        "body_html" => "<p>#{ERB::Util.html_escape(I18n.t("blog.themes.sample_body"))}</p>",
      )
    end

    it "uses the chosen article" do
      assign(:publication, publication)
      assign(:article, article)
      assign(:topic, publication.discussion_topic)

      expect(helper.blog_authoring_template_assigns["article"]["url"]).to eq(publication.url)
    end
  end

  describe "#blog_template_article" do
    let(:topic) { publication.discussion_topic }

    before { freeze_time }

    it "describes an article for listings" do
      topic.update_columns(posts_count: 3)

      values = helper.blog_template_article(publication, article, topic, index: 2)

      expect(values).to include(
        "title" => topic.title,
        "url" => "https://blog.example.com/field-story",
        "excerpt" => "A standfirst",
        "standfirst" => "A standfirst",
        "author" => topic.user.name,
        "published_at" => publication.published_at.iso8601,
        "date" => helper.blog_date(publication.published_at),
        "relative_date" => I18n.t("blog.time_ago", time: "3d"),
        "reading_time" => I18n.t("blog.reading_time", count: 1),
        "featured" => false,
        "image_url" => nil,
        "discussion_url" => topic.url,
        "replies" => 2,
        "replies_label" => I18n.t("blog.replies", count: 2),
        "index" => "03",
        "updated_label" => I18n.t("blog.updated", date: helper.blog_date(Time.current)),
      )
      expect(values).not_to include("body_html", "tags")
    end

    it "omits the update label when the article was not revised on a later day" do
      publication.update_columns(last_published_at: publication.published_at)
      topic.update_columns(posts_count: 0)

      expect(helper.blog_template_article(publication, article, topic)).to include(
        "updated_label" => nil,
        "replies" => 0,
      )
    end

    it "adds the body and public tags for the article page" do
      values = helper.blog_template_article(publication, article, topic, body: true)

      expect(values["body_html"]).to be_a(Blog::TemplateRenderer::Html)
      expect(values["body_html"]).to include(topic.first_post.cooked)
      expect(values["tags"]).to eq(
        [{ "name" => tag.name, "url" => "https://blog.example.com/tag/#{tag.slug}" }],
      )
    end
  end

  describe "#blog_article_schema" do
    it "describes the article for search engines" do
      assign(:publication, publication)
      assign(:article, article)
      assign(:description, "A standfirst")

      expect(JSON.parse(helper.blog_article_schema)).to eq(
        "@context" => "https://schema.org",
        "@type" => "BlogPosting",
        "headline" => article.title,
        "description" => "A standfirst",
        "url" => publication.url,
        "mainEntityOfPage" => publication.url,
        "datePublished" => publication.published_at.iso8601,
        "dateModified" => publication.article_updated_at.iso8601,
        "author" => {
          "@type" => "Person",
          "name" => article.data["author_name"],
        },
      )
    end
  end
end
