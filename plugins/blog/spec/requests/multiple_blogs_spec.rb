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

    it "redirects addresses other blog engines publish to the blog on that domain" do
      host! "engineering.example.com"

      get "/posts"
      expect(response).to redirect_to("https://engineering.example.com/")
      get "/rss"
      expect(response).to redirect_to("https://engineering.example.com/feed.xml")
      get "/page/2"
      expect(response).to redirect_to("https://engineering.example.com/?page=2")
    end

    it "keeps the editor off the blog's domain" do
      sign_in(admin)
      host! "engineering.example.com"

      get "/blog-editor.json"

      expect(response.status).to eq(404)
    end
  end

  describe "in the editor" do
    fab!(:writers, :group)
    fab!(:writer) { Fabricate(:user, groups: [writers], refresh_auto_groups: true) }

    before do
      SiteSetting.blog_contributor_groups = writers.id.to_s
      engineering.update!(path_format: "/{year}/{slug}")
    end

    it "starts a new draft on the blog it was written for" do
      sign_in(writer)

      post "/posts.json",
           params: {
             title: "Notes from the engineering offsite",
             raw: "What we learned while planning the next quarter together.",
             category: drafts.id,
             blog_id: engineering.id,
           }

      expect(response.status).to eq(200)
      publication = Blog::Publication.find_by!(topic_id: response.parsed_body["topic_id"])
      expect(publication).to have_attributes(
        blog_id: engineering.id,
        path: "/#{Time.current.year}/notes-from-the-engineering-offsite",
      )
    end

    it "moves a draft to another blog until it is published" do
      topic = Fabricate(:topic, category: drafts, user: admin, title: "A draft that changes blogs")
      Fabricate(:post, topic:, user: admin)
      sign_in(admin)

      put "/blog-editor/publications/#{topic.id}.json",
          params: {
            publication: {
              blog_id: engineering.id,
            },
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "blog_id" => engineering.id,
        "can_change_blog" => true,
      )
      publication = Blog::Publication.find_by!(topic:)
      expect(publication.path).to eq("/#{Time.current.year}/a-draft-that-changes-blogs")

      publish_blog_draft(publication, admin)
      put "/blog-editor/publications/#{topic.id}.json",
          params: {
            publication: {
              blog_id: Blog::Instance.default_blog.id,
            },
          }

      expect(response.status).to eq(422)
      expect(publication.reload.blog_id).to eq(engineering.id)
    end

    it "gives each listed topic the blog it belongs to, including topics not yet assigned" do
      engineering_article =
        publish_article(engineering, path: "/story", raw: "An engineering story.")
      unassigned = Fabricate(:topic, category: engineering_category, user: admin)
      Fabricate(:post, topic: unassigned, user: admin)
      draft = Fabricate(:topic, category: drafts, user: admin)
      sign_in(admin)

      get "/blog-editor.json"

      blog_ids = response.parsed_body["topics"].to_h { [_1["id"], _1["blog_id"]] }
      expect(blog_ids).to include(
        engineering_article.topic_id => engineering.id,
        unassigned.id => engineering.id,
        draft.id => Blog::Instance.default_blog.id,
      )
    end

    it "lists one blog's work when the editor filters by blog" do
      article = publish_article(engineering, path: "/story", raw: "An engineering story.")
      sign_in(admin)

      get "/blog-editor.json", params: { blog: engineering.id }
      expect(response.parsed_body["topics"].map { _1["id"] }).to contain_exactly(article.topic_id)
      expect(response.parsed_body["blog_url"]).to eq("#{Discourse.base_url}/blog/engineering")

      get "/blog-editor.json", params: { blog: 0 }
      expect(response.status).to eq(404)
    end
  end
end
