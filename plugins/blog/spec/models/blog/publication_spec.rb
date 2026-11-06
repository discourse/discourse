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

  describe ".default_path" do
    before { freeze_time Time.utc(2026, 11, 6, 23, 30) }

    it "uses the slug alone by default" do
      expect(described_class.default_path(topic)).to eq("/#{topic.slug}")
    end

    it "prefixes the UTC year and month" do
      SiteSetting.blog_path_format = "year_month_slug"

      expect(described_class.default_path(topic)).to eq("/2026/11/#{topic.slug}")
      expect(described_class.default_path(topic, date: Time.utc(2025, 2, 3))).to eq(
        "/2025/02/#{topic.slug}",
      )
    end

    it "prefixes the UTC year, month and day" do
      SiteSetting.blog_path_format = "year_month_day_slug"

      expect(
        described_class.default_path(topic, date: Time.zone.parse("2026-11-07 02:00 +04:00")),
      ).to eq("/2026/11/06/#{topic.slug}")
    end
  end

  describe "#stage_metadata" do
    fab!(:topic) { Fabricate(:topic, title: "A dated story for the blog") }

    let(:publication) { described_class.for_topic(topic) }

    before do
      freeze_time Time.utc(2026, 11, 6)
      SiteSetting.blog_path_format = "year_month_slug"
    end

    it "moves a generated dated path to the new publication date" do
      publication.stage_metadata(path: publication.path, published_at: "2025-03-14")

      expect(publication.path).to eq("/2025/03/#{topic.slug}")
    end

    it "keeps a path typed alongside the new date" do
      publication.stage_metadata(path: "/2026/11/my-own-path", published_at: "2025-03-14")

      expect(publication.path).to eq("/2026/11/my-own-path")
    end

    it "keeps a stored path that does not end in the topic slug" do
      publication.update!(path: "/2026/11/hand-picked")

      publication.stage_metadata(path: "/2026/11/hand-picked", published_at: "2025-03-14")

      expect(publication.path).to eq("/2026/11/hand-picked")
    end

    it "keeps the path when the redated one belongs to another article" do
      other = described_class.create!(topic: Fabricate(:topic), path: "/elsewhere")
      other.paths.create!(path: "/2025/03/#{topic.slug}")

      publication.stage_metadata(path: publication.path, published_at: "2025-03-14")

      expect(publication.path).to eq("/2026/11/#{topic.slug}")
    end
  end
end
