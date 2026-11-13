# frozen_string_literal: true

RSpec.describe Blog::ArticleMetadata do
  include_context "with a public blog"

  fab!(:publication) { publish_blog_article(excerpt: "A standfirst") }

  let(:article) { publication.article }

  describe "#schema" do
    it "describes the article for search engines" do
      metadata = described_class.new(publication, description: "A standfirst")

      expect(JSON.parse(metadata.schema)).to eq(
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
          "url" =>
            "https://blog.example.com/author/#{publication.discussion_topic.user.username_lower}",
        },
      )
    end

    it "leaves out the author when the system user owns the article" do
      publication.discussion_topic.update!(user: Discourse.system_user)
      metadata = described_class.new(publication, description: nil)

      expect(JSON.parse(metadata.schema)).not_to have_key("author")
    end

    it "lists every author when the article has co-authors" do
      co_author = Fabricate(:user, name: "Ada")
      credits = Blog::Revision.co_author_credits([co_author.id])
      revision = Blog::Revision.new(data: article.data.merge("co_authors" => credits))
      metadata = described_class.new(publication, revision:, description: nil)

      expect(JSON.parse(metadata.schema)["author"]).to contain_exactly(
        include("name" => article.data["author_name"]),
        {
          "@type" => "Person",
          "name" => "Ada",
          "url" => "https://blog.example.com/author/#{co_author.username_lower}",
        },
      )
    end

    it "includes the article image" do
      revision = Blog::Revision.new(data: article.data.merge("image_url" => "/uploads/cover.png"))
      metadata = described_class.new(publication, revision:, description: nil)

      expect(JSON.parse(metadata.schema)["image"]).to eq("http://test.localhost/uploads/cover.png")
    end
  end

  describe "#twitter_card" do
    it "uses a large card only when the article has an image" do
      with_image = Blog::Revision.new(data: article.data.merge("image_url" => "/uploads/cover.png"))

      expect(described_class.new(publication, description: nil).twitter_card).to eq("summary")
      expect(
        described_class.new(publication, revision: with_image, description: nil).twitter_card,
      ).to eq("summary_large_image")
    end
  end
end
