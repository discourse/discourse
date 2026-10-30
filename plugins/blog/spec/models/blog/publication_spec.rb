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
      ]

      paths.each do |path|
        publication = described_class.new(topic: topic, path: path)
        expect(publication).not_to be_valid, "Expected #{path.inspect} to be rejected"
        expect(publication.errors[:path]).to be_present
      end
    end
  end
end
