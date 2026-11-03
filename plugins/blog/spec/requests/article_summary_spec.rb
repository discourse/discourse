# frozen_string_literal: true

RSpec.describe "Blog article summaries", type: :request do
  fab!(:admin)
  fab!(:category)
  fab!(:drafts) { Fabricate(:private_category, group: Group[:staff]) }
  fab!(:topic) { Fabricate(:topic, category: drafts, user: admin) }
  fab!(:first_post) do
    Fabricate(
      :post,
      topic: topic,
      user: admin,
      raw: ("A practical workflow worth explaining. " * 60),
    )
  end

  before do
    enable_blog!(category: category, drafts: drafts)
    @publication = Blog::Publication.for_topic(topic)
    @publication.save_metadata!(admin, path: "/workflow", excerpt: "An editorial summary.")
  end

  it "provides an excerpt and blog link without replacing the full cooked post" do
    @publication.publish!(admin)
    get "/t/#{@publication.discussion_topic_id}.json"

    expect(response.status).to eq(200)
    post = response.parsed_body["post_stream"]["posts"].first
    expect(post["blog_article"]).to eq(
      "url" => @publication.url,
      "excerpt" => @publication.excerpt,
      "blog_name" => SiteSetting.blog_title,
    )
    expect(post["cooked"]).to eq(first_post.reload.cooked)
  end

  it "leaves short published posts uncompressed" do
    first_post.revise(admin, raw: "A short announcement that should remain fully visible.")
    @publication.publish!(admin)
    get "/t/#{@publication.discussion_topic_id}.json"

    expect(response.parsed_body["post_stream"]["posts"].first["blog_article"]).to be_nil
  end

  it "does not offer summaries for private drafts, even to editors" do
    sign_in(admin)
    get "/t/#{topic.id}.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["post_stream"]["posts"].first["blog_article"]).to be_nil
  end

  it "removes summary metadata when an article is unpublished" do
    @publication.publish!(admin)
    @publication.unpublish!(admin)
    get "/t/#{@publication.discussion_topic_id}.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["post_stream"]["posts"].first["blog_article"]).to be_nil
  end
end
