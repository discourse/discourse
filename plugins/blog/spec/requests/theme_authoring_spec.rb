# frozen_string_literal: true

RSpec.describe "Blog theme authoring", type: :request do
  fab!(:admin)
  fab!(:user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:first_post) { Fabricate(:post, topic: topic) }
  fab!(:publication) do
    Blog::Publication.create!(
      topic: topic,
      discussion_topic: topic,
      path: "/sample",
      published: true,
      published_at: 1.day.ago,
    )
  end
  fab!(:publication_path) { Blog::Path.create!(publication: publication, path: "/sample") }
  fab!(:private_category) { Fabricate(:private_category, group: Group[:staff]) }
  fab!(:private_topic) { Fabricate(:topic, category: private_category) }
  fab!(:private_post) do
    Fabricate(
      :post,
      topic: private_topic,
      raw: "Confidential editorial material that must never enter template previews.",
    )
  end

  let(:attributes) do
    Blog::BlogTheme.defaults.merge(
      "name" => "Unsaved working design",
      "template_index" => "<h1 data-working>{{ site.title }}</h1>",
    )
  end

  before do
    enable_blog!(category: category)
    https!
    SiteSetting.force_https = true
  end

  it "requires administrators and serves only public samples" do
    get "https://test.localhost/blog/theme-authoring.json"
    expect(response.status).to eq(403)
    get "https://test.localhost/session/#{user.encoded_username}/become"
    get "https://test.localhost/blog/theme-authoring.json"
    expect(response.status).to eq(403)
    get "https://test.localhost/session/#{admin.encoded_username}/become"
    get "https://test.localhost/blog/theme-authoring.json"
    expect(response.status).to eq(200)
    data = response.parsed_body
    expect(data["templates"]["template_layout"]).to include("{{ content_html }}")
    expect(data["articles"].map { |article| article["id"] }).to eq([publication.id])
    expect(data.dig("variables", "article", "title")).to eq(publication.article.title)
    expect(response.body).not_to include(private_post.raw, private_topic.title)
    get "https://blog.example.com/blog/theme-authoring.json"
    expect(response.status).to eq(404)
  end

  it "previews unsaved changes without saving or activating and expires the capability" do
    freeze_time
    get "https://test.localhost/session/#{admin.encoded_username}/become"
    post "https://test.localhost/blog/theme-authoring/preview.json",
         params: {
           theme: attributes,
           page: "index",
         }
    expect(response.status).to eq(201)
    url = response.parsed_body["url"]
    expect(Blog::BlogTheme.all).to be_empty
    expect(Blog::BlogTheme.active["name"]).not_to eq(attributes["name"])
    get url
    expect(response.status).to eq(200)
    expect(response.body).to include("data-working")
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.headers["Content-Security-Policy"]).to include(
      "frame-ancestors https://test.localhost",
    )
    expect(response.headers["X-Frame-Options"]).to be_nil
    get "https://blog.example.com/"
    expect(response.body).not_to include("data-working")
    freeze_time 16.minutes.from_now
    get url
    expect(response.status).to eq(404)
  end

  it "shows syntax errors with template and line instead of silently substituting live output" do
    get "https://test.localhost/session/#{admin.encoded_username}/become"
    post "https://test.localhost/blog/theme-authoring/preview.json",
         params: {
           theme: attributes.merge("template_index" => "<h1>Broken</h1>\n{% unknown_tag %}"),
           page: "index",
         }
    expect(response.status).to eq(201)
    get response.parsed_body["url"]
    expect(response.body).to include('data-template-diagnostic="error"', "index, line 2")
    expect(Blog::BlogTheme.all).to be_empty
  end

  it "warns about undefined variables while rendering the rest of the working page" do
    get "https://test.localhost/session/#{admin.encoded_username}/become"
    post "https://test.localhost/blog/theme-authoring/preview.json",
         params: {
           theme:
             attributes.merge(
               "template_index" => "<h1 data-working>{{ site.title }}</h1>\n{{ missing_value }}",
             ),
           page: "index",
         }
    expect(response.status).to eq(201)
    get response.parsed_body["url"]
    expect(response.body).to include(
      'data-template-diagnostic="warning"',
      "missing_value",
      "data-working",
    )
  end

  it "selects public article previews and keeps only three working snapshots per editor" do
    get "https://test.localhost/session/#{admin.encoded_username}/become"
    urls =
      4.times.map do
        post "https://test.localhost/blog/theme-authoring/preview.json",
             params: {
               theme: attributes,
               page: "article",
               article_id: publication.id,
             }
        expect(response.status).to eq(201)
        response.parsed_body["url"]
      end
    get urls.first
    expect(response.status).to eq(404)
    get urls.last
    expect(response.status).to eq(200)
    expect(response.body).to include(first_post.cooked)
    post "https://test.localhost/blog/theme-authoring/preview.json",
         params: {
           theme: attributes,
           page: "article",
           article_id: -1,
         }
    expect(response.status).to eq(404)
  end
end
