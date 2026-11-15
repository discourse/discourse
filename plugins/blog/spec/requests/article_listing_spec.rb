# frozen_string_literal: true

RSpec.describe "Blog article listing", type: :request do
  include_context "with a public blog"

  fab!(:older_publication) { publish_blog_article(published_at: 2.days.ago) }
  fab!(:newer_publication) { publish_blog_article(published_at: 1.day.ago) }

  before { SiteSetting.blog_posts_per_page = 1 }

  it "pages through articles with canonical and neighbouring links" do
    get "https://blog.example.com/", params: { page: 0 }
    html = Nokogiri.HTML5(response.body)
    expect(response.status).to eq(200)
    expect(html.at_css('link[rel="canonical"]')["href"]).to eq("https://blog.example.com/")
    expect(html.at_css('a[rel="next"]')["href"]).to eq("https://blog.example.com/?page=2")
    expect(response.body).to include(newer_publication.url)

    get "https://blog.example.com/", params: { page: 2 }
    html = Nokogiri.HTML5(response.body)
    expect(html.at_css('link[rel="canonical"]')["href"]).to eq("https://blog.example.com/?page=2")
    expect(html.at_css('a[rel="prev"]')["href"]).to eq("https://blog.example.com/?page=1")
    expect(html.at_css('a[rel="next"]')).to be_nil
    expect(response.body).to include(older_publication.url)
  end
end
