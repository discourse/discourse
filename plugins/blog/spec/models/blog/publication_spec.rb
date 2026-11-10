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

    it "follows a remap and rebake of the discussion post" do
      stub_request(:any, "https://new.example.com/guide").to_return(status: 404)
      discussion_post.revise(
        Discourse.system_user,
        { raw: discussion_post.raw.sub("old.example.com", "new.example.com") },
        skip_revision: true,
        bypass_bump: true,
      )
      CookedPostProcessor.new(discussion_post.reload).post_process

      expect(publication.reload.article.cooked).to include("https://new.example.com/guide")
    end

    it "follows a hostname remap of the database" do
      DbHelper.remap("old.example.com", "new.example.com")

      expect(publication.reload.article.cooked).to include("https://new.example.com/guide")
    end

    it "keeps the published HTML when the discussion post is edited outside a publish" do
      published_cooked = publication.article.cooked
      discussion_post.revise(
        acting_user,
        { raw: "An unapproved change to the live article." },
        force_new_version: true,
      )
      CookedPostProcessor.new(discussion_post.reload).post_process

      expect(publication.reload.article.cooked).to eq(published_cooked)
    end

    it "shows the revision snapshot until the live HTML is captured" do
      publication.update_columns(cooked: nil)

      expect(publication.article.cooked).to eq(publication.published_revision.cooked)
    end
  end
end
