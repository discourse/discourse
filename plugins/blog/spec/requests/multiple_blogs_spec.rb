# frozen_string_literal: true

RSpec.describe "Several blogs", type: :request do
  fab!(:admin)
  fab!(:category)
  fab!(:engineering_category, :category)
  fab!(:drafts) { Fabricate(:private_category, group: Group[:staff]) }

  let(:engineering) do
    Blog::Instance.create!(name: "Engineering", slug: "engineering", category: engineering_category)
  end

  before do
    enable_blog!(category:, drafts:, custom_domain: false)
    RailsMultisite::ConnectionManagement.stubs(:current_db_hostnames).returns(
      [BlogSpecHelpers::DISCUSSION_HOST, BlogSpecHelpers::BLOG_HOST, "engineering.example.com"],
    )
  end

  def publish_article(blog, path:, raw:)
    topic = Fabricate(:topic, category: drafts, user: admin)
    Fabricate(:post, topic:, user: admin, raw:)
    publication = Blog::Publication.for_topic(topic)
    publication.blog = blog
    publication.save!
    update_blog_metadata(publication, admin, path:)
    publish_blog_draft(publication, admin)
  end

  describe "without custom domains" do
    let!(:main_article) do
      publish_article(Blog::Instance.default_blog, path: "/story", raw: "A story on the main blog.")
    end
    let!(:engineering_article) do
      publish_article(engineering, path: "/story", raw: "A story on the engineering blog.")
    end

    it "serves each blog at its own address, with its own articles" do
      get "/blog/story"
      expect(response.body).to include(main_article.discussion_topic.first_post.raw)

      get "/blog/engineering/story"
      expect(response.status).to eq(200)
      expect(response.body).to include(engineering_article.discussion_topic.first_post.raw)
      expect(Nokogiri.HTML5(response.body).at_css('link[rel="canonical"]')["href"]).to eq(
        "#{Discourse.base_url}/blog/engineering/story",
      )

      get "/blog/engineering"
      expect(response.body).to include(engineering_article.url)
      expect(response.body).not_to include(main_article.url)

      get "/blog/engineering/feed.xml"
      expect(response.body).to include(engineering_article.url)
      expect(response.body).not_to include(main_article.url)

      %w[/blog/engineering/about /blog/engineering/sitemap.xml].each do |path|
        get path
        expect(response.status).to eq(200)
      end
    end

    it "keeps another blog under the forum when the default blog moves to its own domain" do
      SiteSetting.blog_url = "https://#{BlogSpecHelpers::BLOG_HOST}"

      get "/blog/engineering/story"
      expect(response.status).to eq(200)

      get "/blog/story"
      expect(response).to redirect_to("https://#{BlogSpecHelpers::BLOG_HOST}/story")

      draft = Fabricate(:topic, category: drafts, user: admin)
      Fabricate(:post, topic: draft, user: admin)
      Blog::Publication.for_topic(draft).tap { _1.blog = engineering }.save!
      review = issue_blog_review(draft, user: admin)
      expect(review.url).to start_with("#{Discourse.base_url}/blog/review?")
      get review.url
      expect(response.status).to eq(200)
    end

    it "gives each draft a review link on its own blog's address" do
      engineering.update!(url: "https://engineering.example.com")
      review = issue_blog_review(engineering_article.editable_topic, user: admin)

      expect(review.url).to start_with("https://engineering.example.com/blog/review?")
    end
  end

  describe "with a blog on its own domain" do
    before { engineering.update!(url: "https://engineering.example.com") }

    let!(:engineering_article) do
      publish_article(engineering, path: "/story", raw: "A story on the engineering blog.")
    end

    it "serves the blog on its domain and redirects its forum address there" do
      host! "engineering.example.com"
      get "/story"
      expect(response.status).to eq(200)
      expect(response.body).to include(engineering_article.discussion_topic.first_post.raw)

      host! BlogSpecHelpers::DISCUSSION_HOST
      get "/blog/engineering/story"
      expect(response).to redirect_to("https://engineering.example.com/story")
    end

    it "keeps the editor off the blog's domain" do
      sign_in(admin)
      host! "engineering.example.com"

      get "/blog-editor.json"

      expect(response.status).to eq(404)
    end
  end
end
