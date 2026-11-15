# frozen_string_literal: true

RSpec.describe Blog::TemplateVariables do
  include_context "with a public blog"

  fab!(:tag) { Fabricate(:tag, name: "field-notes") }
  fab!(:publication) { publish_blog_article(path: "/field-story") }

  describe "#to_h" do
    it "describes the site and an unfiltered listing" do
      SiteSetting.blog_about = "We publish **field notes**."

      variables = described_class.new(title: "Home", publications: [publication]).to_h

      expect(variables["site"]).to include(
        "title" => SiteSetting.blog_title,
        "url" => "https://blog.example.com/",
        "archive_url" => "https://blog.example.com/archive",
        "feed_url" => "https://blog.example.com/feed.xml",
        "editor_url" => "#{Discourse.base_url}/blog-editor",
      )
      expect(variables["site"]["about_html"]).to include("<strong>field notes</strong>")
      expect(variables["page"]).to include(
        "title" => "Home",
        "heading" => SiteSetting.blog_title,
        "eyebrow" => I18n.t("blog.from_the_blog"),
        "archive" => false,
        "previous_url" => nil,
        "next_url" => nil,
      )
      expect(variables["labels"]).to include("archive" => I18n.t("blog.archive"))
      expect(variables["articles"].map { |article| article["url"] }).to eq([publication.url])
      expect(variables["article"]).to be_nil
    end

    it "links neighbouring archive pages, keeping the search and theme preview" do
      variables =
        described_class.new(
          path: "/archive",
          archive: true,
          page: 2,
          more: true,
          query: "needle",
          preview_token: "preview-token",
        ).to_h

      expect(variables["page"]).to include(
        "heading" => I18n.t("blog.archive"),
        "archive" => true,
        "query" => "needle",
        "preview_token" => "preview-token",
        "previous_url" =>
          "https://blog.example.com/archive?page=1&q=needle&blog_theme_preview=preview-token",
        "next_url" =>
          "https://blog.example.com/archive?page=3&q=needle&blog_theme_preview=preview-token",
      )
      expect(variables["site"]["url"]).to eq(
        "https://blog.example.com/?blog_theme_preview=preview-token",
      )
    end

    it "names the tag on tag pages" do
      expect(described_class.new(tag:).to_h["page"]).to include(
        "heading" => tag.name,
        "eyebrow" => I18n.t("blog.tagged", tag: tag.name),
      )
    end

    it "describes the page with the blog description" do
      SiteSetting.blog_description = "Notes & stories"

      variables = described_class.new(tag:)

      expect(variables.description).to eq("Notes & stories")
      expect(variables.to_h["page"]).to include(
        "description" => "Notes & stories",
        "description_html" => "<p>Notes &amp; stories</p>",
      )
    end

    it "describes tag pages with the tag's description" do
      tag.update!(description: "Dispatches from [the field](/c/field).")

      variables = described_class.new(tag:)

      expect(variables.description).to eq("Dispatches from the field.")
      expect(variables.to_h["page"]["description_html"]).to include(
        "<a href=\"#{Discourse.base_url}/c/field\">the field</a>",
      )
    end

    it "leaves the description out when the blog has none" do
      SiteSetting.blog_description = ""

      expect(described_class.new.to_h["page"]["description_html"]).to be_nil
    end

    it "includes the full article on article pages" do
      article = Blog::ArticleVariables.new(publication)

      expect(described_class.new(article:).to_h["article"]).to include(
        "url" => publication.url,
        "body_html" => be_present,
      )
    end
  end
end
