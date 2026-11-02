# frozen_string_literal: true

RSpec.describe "Blog editor filtering", type: :request do
  fab!(:admin)
  fab!(:category)
  fab!(:drafts) { Fabricate(:private_category, group: Group[:staff]) }
  fab!(:published_topic) do
    Fabricate(:topic, category: category, user: admin, title: "Published workflow")
  end
  fab!(:published_post) { Fabricate(:post, topic: published_topic, user: admin) }
  fab!(:publication) do
    Blog::Publication.create!(
      topic: published_topic,
      discussion_topic: published_topic,
      path: "/special-workflow",
      excerpt: "A summary",
      published: true,
      published_at: 2.days.ago,
    )
  end

  before do
    enable_blog!(category: category, drafts: drafts)
    sign_in(admin)
  end

  it "filters the entire collection before applying the page limit" do
    published_topic.update_column(:updated_at, 3.days.ago)
    Fabricate.times(Blog::EditorController::PAGE_SIZE + 1, :topic, category: drafts)

    get "/blog-editor.json", params: { filter: "published" }

    expect(response.status).to eq(200)
    expect(response.parsed_body["topics"].map { |entry| entry["id"] }).to eq([published_topic.id])
    expect(response.parsed_body["more"]).to eq(false)
  end

  it "paginates search results in a stable order within the selected status" do
    matching =
      (Blog::EditorController::PAGE_SIZE + 1).times.map do |index|
        Fabricate(:topic, category: drafts, title: "Needle article #{index}")
      end
    Topic.where(id: matching.map(&:id)).update_all(updated_at: 1.day.ago)
    Fabricate(:topic, category: drafts, title: "Unrelated newer draft")
    Fabricate(:topic, title: "Needle outside editorial categories")

    get "/blog-editor.json", params: { filter: "drafts", q: "NEEDLE" }
    expect(response.status).to eq(200)
    expect(response.parsed_body["topics"].map { |entry| entry["id"] }).to eq(
      matching.reverse.first(Blog::EditorController::PAGE_SIZE).map(&:id),
    )
    expect(response.parsed_body["more"]).to eq(true)

    get "/blog-editor.json", params: { filter: "drafts", q: "NEEDLE", page: 1 }
    expect(response.parsed_body["topics"].map { |entry| entry["id"] }).to eq([matching.first.id])
    expect(response.parsed_body["more"]).to eq(false)
  end

  it "searches stored article paths and treats wildcard characters literally" do
    get "/blog-editor.json", params: { q: "special-workflow" }
    expect(response.parsed_body["topics"].map { |entry| entry["id"] }).to eq([published_topic.id])

    literal = Fabricate(:topic, category: drafts, title: "A 100%_literal example")
    Fabricate(:topic, category: drafts, title: "An unrelated example")
    get "/blog-editor.json", params: { q: "%_" }
    expect(response.parsed_body["topics"].map { |entry| entry["id"] }).to eq([literal.id])
  end

  it "separates unpublished public topics from private drafts and live articles" do
    unpublished = Fabricate(:topic, category: category)
    Fabricate(:topic, category: drafts)

    get "/blog-editor.json", params: { filter: "unpublished" }

    expect(response.parsed_body["topics"].map { |entry| entry["id"] }).to eq([unpublished.id])
  end

  it "rejects invalid filters and oversized or structured search input" do
    get "/blog-editor.json", params: { filter: "invalid" }
    expect(response.status).to eq(400)
    get "/blog-editor.json", params: { q: "a" * 101 }
    expect(response.status).to eq(400)
    get "/blog-editor.json", params: { q: { title: "test" } }
    expect(response.status).to eq(400)
  end
end
