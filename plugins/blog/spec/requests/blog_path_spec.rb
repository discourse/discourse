# frozen_string_literal: true

RSpec.describe "Blog under /blog", type: :request do
  fab!(:admin)
  fab!(:category)
  fab!(:drafts) { Fabricate(:private_category, group: Group[:staff]) }
  fab!(:topic) { Fabricate(:topic, category: drafts, user: admin) }
  fab!(:first_post) do
    Fabricate(:post, topic: topic, user: admin, raw: "An article published under the forum.")
  end

  before { enable_blog!(category: category, drafts: drafts, custom_domain: false) }

  let!(:publication) do
    publication = Blog::Publication.for_topic(topic)
    publication.path = "/first-story"
    publication.publish!(admin)
    publication
  end

  it "serves articles, listings and feeds under /blog" do
    get "/blog/first-story"
    expect(response.status).to eq(200)
    html = Nokogiri.HTML5(response.body)
    expect(html.at_css('link[rel="canonical"]')["href"]).to eq(publication.url)
    expect(html.at_css(".blog-article__body").text).to include(first_post.raw)

    %w[/blog /blog/archive /blog/feed.xml /blog/sitemap.xml /blog/about].each do |path|
      get path
      expect(response.status).to eq(200)
    end
    get "/blog/feed.xml"
    expect(response.body).to include(publication.url)
  end

  it "leaves the forum's own paths and robots.txt alone" do
    get "/first-story"
    expect(response.body).not_to include(first_post.raw)

    get "/robots.txt"
    expect(response.body).not_to include("/blog/sitemap.xml")
    get "/blog/robots.txt"
    expect(response.status).to eq(404)
  end

  it "redirects an old article path to its current one" do
    old_url = publication.url
    publication.save_metadata!(admin, path: "/renamed-story")
    publication.publish!(admin)

    get old_url
    expect(response.status).to eq(301)
    expect(response).to redirect_to("#{Discourse.base_url}/blog/renamed-story")
  end

  it "keeps the editor outside the public blog" do
    sign_in(admin)
    get "/blog-editor.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["blog_url"]).to eq("#{Discourse.base_url}/blog")
  end

  it "serves review links from the forum origin" do
    sign_in(admin)
    post "/blog-editor/publications/#{topic.id}/reviews.json"
    expect(response.status).to eq(201)
    url = response.parsed_body.dig("review", "url")
    expect(url).to start_with("#{Discourse.base_url}/blog/review?")
    token = Rack::Utils.parse_query(URI(url).query)["review_token"]

    get "/blog/review.json", params: { review_token: token }
    expect(response.status).to eq(200)
    expect(response.parsed_body["title"]).to eq(topic.title)

    post "/blog/review/feedback.json",
         params: {
           review_token: token,
           feedback: {
             message: "Looks good",
           },
         },
         headers: {
           "Origin" => Discourse.base_url_no_prefix,
         }
    expect(response.status).to eq(204)
  end

  it "can be chosen as the homepage" do
    SiteSetting.default_homepage = "blog"

    get "/"
    expect(response.status).to eq(200)
    expect(Nokogiri.HTML5(response.body).at_css("body.blog")).to be_present
    expect(response.body).to include(publication.url)
  end

  it "sends the blog's base URL to the client" do
    get "/site.json"
    expect(response.parsed_body["blog_base_url"]).to eq("#{Discourse.base_url}/blog")
  end

  describe "with a custom domain" do
    before { enable_blog!(category: category, drafts: drafts) }

    it "redirects /blog on the forum to the blog's hostname" do
      get "/blog/first-story?ref=1"
      expect(response.status).to eq(302)
      expect(response).to redirect_to("https://blog.example.com/first-story?ref=1")

      get "/blog"
      expect(response).to redirect_to("https://blog.example.com/")
    end

    it "no longer offers the blog as a homepage" do
      expect(HomepageSiteSetting.choices).not_to include("blog")
    end
  end
end
