# frozen_string_literal: true

RSpec.describe Blog::Publication do
  fab!(:topic)

  describe "path validation" do
    it "rejects ambiguous paths, traversal, and reserved endpoints" do
      paths = %w[
        //example.com/story
        https://example.com/story
        /story?query=1
        /story#fragment
        /a/../story
        /a/./story
        /a//story
        /a/%2e%2e/story
        /a%2Fstory
        /a%5cstory
        /a%252fstory
        /a%00story
        /a%ZZstory
        /blog/editor
        /blog/other/story
        /blog/archive/../story
        /posts
        /posts.rss
        /posts.atom
        /feed.xml
        /sitemap.xml
        /robots.txt
        /blog-theme.css
        /blog-custom.js
        /blog-highlight/version.js
        /uploads/story
        /archive
        /archive.rss
        /about.json
        /About
        /tag/story
        /author/story
        /page/2
        /rss
        /feed
        /review
        /session/story
        /assets/story
        /message-bus/story
        /auth/story
        /mini-profiler-resources/story
      ]

      paths.each do |path|
        publication = described_class.new(topic: topic, path: path)
        expect(publication).not_to be_valid, "Expected #{path.inspect} to be rejected"
        expect(publication.errors[:path]).to be_present
      end
    end

    it "accepts article paths outside reserved segments" do
      paths = %w[
        /first-story
        /2024/annual-report
        /about-us.html
        /authors
        /archive/2011/03/30/story
        /blog/archive/2020/01/02/story
        /admin
        /u/someone
        /t/123
        /latest
        /privacy
        /chat
        /blog-editor
      ]

      paths.each do |path|
        publication = described_class.new(topic: topic, path: path)
        expect(publication).to be_valid, "Expected #{path.inspect} to be accepted"
      end
    end

    it "accepts percent-encoded UTF-8 and stores it in upper case" do
      publication = described_class.new(topic:, path: "/2024/%e6%97%a5%e6%9c%ac-%2b")

      expect(publication).to be_valid
      expect(publication.path).to eq("/2024/%E6%97%A5%E6%9C%AC-%2B")
    end

    it "rejects encoded ASCII, invalid UTF-8, and invisible or unassigned characters" do
      %w[
        /%41story
        /%20story
        /%7Estory
        /%E6story
        /%FFstory
        /%C3%28story
        /%C0%AE%C0%AE
        /%E2%80%AEstory
        /%E2%80%8Bstory
        /%C2%A0story
        /%E3%80%80story
        /%EE%80%80story
        /%F4%8F%BF%BFstory
      ].each do |path|
        publication = described_class.new(topic:, path:)
        expect(publication).not_to be_valid, "Expected #{path.inspect} to be rejected"
        expect(publication.errors[:path]).to be_present
      end
    end

    it "reserves the first segment of every blog route served beside articles" do
      blog_host = Blog::Routes.const_get(:ON_BLOG_HOST)
      paths =
        Rails.application.routes.routes.filter_map do |route|
          next if !route.app.respond_to?(:constraints) || route.app.constraints.exclude?(blog_host)
          route.path.spec.to_s.delete_suffix("(.:format)").gsub(/:\w+/, "story")
        end
      shared_paths = paths - %w[/ /*path]

      expect(shared_paths).to include("/feed.xml")
      expect(shared_paths.reject { |path| described_class.reserved_path?(path) }).to be_empty
    end

    it "keeps an existing article valid when its path becomes reserved" do
      publication = described_class.create!(topic: topic, path: "/story")
      publication.update_columns(path: "/review")

      publication.update!(excerpt: "Updated")
      expect(publication.reload.excerpt).to eq("Updated")

      publication.path = "/tag"
      expect(publication).not_to be_valid
    end
  end

  describe ".for_topic" do
    it "suffixes the topic id when the topic's slug is reserved" do
      reserved_topic = Fabricate(:topic)
      reserved_topic.update_columns(slug: "about")

      expect(described_class.for_topic(topic).path).to eq("/#{topic.slug}")
      expect(described_class.for_topic(reserved_topic).path).to eq("/about-#{reserved_topic.id}")
    end
  end

  describe "#article" do
    include_context "with blog editorial setup"

    fab!(:topic) { Fabricate(:topic, category: drafts, user: writer) }
    fab!(:first_post) do
      Fabricate(
        :post,
        topic:,
        user: writer,
        raw: "Read the guide at https://old.example.com/guide today.",
      )
    end

    let(:discussion_post) { publication.discussion_topic.first_post }

    before { publish_blog_draft(publication, acting_user) }

    it "follows a hostname remap of the database" do
      DbHelper.remap("old.example.com", "new.example.com")

      expect(publication.reload.article.cooked).to include("https://new.example.com/guide")
    end

    it "keeps the approved HTML when the discussion post is rebaked" do
      published_cooked = publication.article.cooked
      discussion_post.update_columns(raw: "Content that changed after approval.")
      CookedPostProcessor.new(discussion_post.reload).post_process

      expect(publication.reload.article.cooked).to eq(published_cooked)
    end

    it "shows the revision snapshot until the live HTML is captured" do
      publication.update_columns(cooked: nil)

      expect(publication.article.cooked).to eq(publication.published_revision.cooked)
    end
  end

  describe ".default_path" do
    before { freeze_time Time.utc(2026, 11, 6, 23, 30) }

    it "uses the slug alone by default" do
      expect(described_class.default_path(topic)).to eq("/#{topic.slug}")
    end

    it "prefixes the UTC year and month" do
      SiteSetting.blog_path_format = "/{year}/{month}/{slug}"

      expect(described_class.default_path(topic)).to eq("/2026/11/#{topic.slug}")
      expect(described_class.default_path(topic, date: Time.utc(2025, 2, 3))).to eq(
        "/2025/02/#{topic.slug}",
      )
    end

    it "prefixes the UTC year, month and day" do
      SiteSetting.blog_path_format = "/{year}/{month}/{day}/{slug}"

      expect(
        described_class.default_path(topic, date: Time.zone.parse("2026-11-07 02:00 +04:00")),
      ).to eq("/2026/11/06/#{topic.slug}")
    end

    it "suffixes a reserved slug wherever the format places it" do
      SiteSetting.blog_path_format = "/{slug}/{id}"
      topic.update_columns(slug: "about")

      path = described_class.default_path(topic)

      expect(path).to eq("/about-#{topic.id}/#{topic.id}")
      expect(described_class.new(topic:, path:)).to be_valid
    end

    it "builds valid paths from encoded slugs, shortening them between characters" do
      SiteSetting.slug_generation_method = "encoded"
      topic.update!(title: "日本の記事について " * 12)

      path = described_class.default_path(topic)

      expect(path).to start_with("/%E6%97%A5%E6%9C%AC")
      expect(path.length).to be <= described_class::MAX_PATH_LENGTH
      expect(described_class.new(topic:, path:)).to be_valid
    end

    it "drops invisible characters that encoded slugs keep from the title" do
      {
        "bonjour%C2%A0" => "/bonjour",
        "%E6%97%A5%E2%80%8B%E6%9C%AC" => "/%E6%97%A5%E6%9C%AC",
        "%E2%80%8B-%E2%80%AE" => "/#{topic.id}",
      }.each do |slug, path|
        topic.update_columns(slug:)

        expect(described_class.default_path(topic)).to eq(path)
        expect(described_class.new(topic:, path:)).to be_valid
      end
    end

    it "shortens a long slug to fit the format within the path limit" do
      SiteSetting.blog_path_format = "/{year}/{month}/{slug}"
      topic.update_columns(slug: "a" * 235)

      path = described_class.default_path(topic)

      expect(path).to eq("/2026/11/#{"a" * 231}")
      expect(described_class.new(topic:, path:)).to be_valid
    end

    it "renders a custom format with a fixed prefix and the topic id" do
      SiteSetting.blog_path_format = "/news/{id}-{slug}"

      expect(described_class.default_path(topic)).to eq("/news/#{topic.id}-#{topic.slug}")
    end
  end

  describe "#stage_metadata" do
    fab!(:topic) { Fabricate(:topic, title: "A dated story for the blog") }

    let(:publication) { described_class.for_topic(topic) }

    before do
      freeze_time Time.utc(2026, 11, 6)
      SiteSetting.blog_path_format = "/{year}/{month}/{slug}"
    end

    it "moves a generated dated path to the new publication date" do
      publication.stage_metadata(path: publication.path, published_at: "2025-03-14")

      expect(publication.path).to eq("/2025/03/#{topic.slug}")
    end

    it "keeps a path typed alongside the new date" do
      publication.stage_metadata(path: "/2026/11/my-own-path", published_at: "2025-03-14")

      expect(publication.path).to eq("/2026/11/my-own-path")
    end

    it "keeps a typed dated path that ends in the topic slug when the date changes later" do
      publication.stage_metadata(path: "/2020/03/#{topic.slug}")

      publication.stage_metadata(path: "/2020/03/#{topic.slug}", published_at: "2025-03-14")

      expect(publication.path).to eq("/2020/03/#{topic.slug}")
    end

    it "renders a stored path the editor never typed, such as an imported undated draft" do
      publication.update!(path: "/imported-draft")

      publication.stage_metadata(path: "/imported-draft", published_at: "2025-03-14")

      expect(publication.path).to eq("/2025/03/#{topic.slug}")
    end

    it "keeps the path when the redated one belongs to another article" do
      other = described_class.create!(topic: Fabricate(:topic), path: "/elsewhere")
      other.paths.create!(path: "/2025/03/#{topic.slug}")

      publication.stage_metadata(path: publication.path, published_at: "2025-03-14")

      expect(publication.path).to eq("/2026/11/#{topic.slug}")
    end
  end

  describe "search metadata" do
    it "accepts an absolute http or https canonical URL, without surrounding spaces" do
      publication =
        described_class.new(topic:, path: "/story", canonical_url: " https://example.com/a ")

      expect(publication).to be_valid
      expect(publication.canonical_url).to eq("https://example.com/a")
    end

    it "rejects canonical URLs that aren't absolute http or https addresses" do
      [
        "/relative",
        "example.com/a",
        "ftp://example.com/a",
        "javascript:alert(1)",
        "https://",
        "http://exa mple.com",
      ].each do |canonical_url|
        publication = described_class.new(topic:, path: "/story", canonical_url:)
        expect(publication).not_to be_valid, "Expected #{canonical_url.inspect} to be rejected"
        expect(publication.errors[:canonical_url]).to be_present
      end
    end

    it "limits the meta description" do
      expect(
        described_class.new(topic:, path: "/story", meta_description: "a" * 501),
      ).not_to be_valid
    end
  end
end
