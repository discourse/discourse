# frozen_string_literal: true

RSpec.describe "Blog publication panel", type: :request do
  fab!(:admin)
  fab!(:user)
  fab!(:category)
  fab!(:drafts) { Fabricate(:private_category, group: Group[:staff]) }
  fab!(:topic) { Fabricate(:topic, category: drafts, user: admin) }
  fab!(:first_post) do
    Fabricate(:post, topic: topic, user: admin, raw: "An article ready to publish.")
  end

  before do
    enable_blog!(category: category, drafts: drafts)
    SiteSetting.editing_grace_period = 0
  end

  it "exposes the editorial state of a draft topic to editors" do
    sign_in(admin)
    get "/t/#{topic.id}.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["blog_publication"]).to include(
      "id" => topic.id,
      "role" => "draft",
      "status" => "draft",
      "can_publish" => true,
      "changes" => [],
      "edits_since_publish" => 0,
      "path" => "/#{topic.slug}",
    )

    other = Fabricate(:topic, user: admin)
    Fabricate(:post, topic: other, user: admin)
    get "/t/#{other.id}.json"
    expect(response.parsed_body).not_to have_key("blog_publication")
  end

  it "publishes the current draft in one step and then reports drift from the live revision" do
    sign_in(admin)
    post "/blog-editor/publications/#{topic.id}/publish.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body).to include("status" => "live", "published" => true)

    publication = Blog::Publication.find_by!(topic: topic)
    discussion = publication.discussion_topic
    get "/t/#{discussion.id}.json"
    expect(response.parsed_body["blog_publication"]).to include(
      "role" => "discussion",
      "status" => "live",
      "source_url" => topic.url,
    )

    first_post.revise(admin, raw: "A corrected article body ready for another release.")
    topic.update!(title: "A corrected title for the article")
    get "/t/#{topic.id}.json"
    entry = response.parsed_body["blog_publication"]
    expect(entry).to include("role" => "draft", "status" => "changes_pending")
    expect(entry["changes"]).to contain_exactly("title", "body")
    expect(entry["edits_since_publish"]).to eq(1)

    get "/blog-editor/publications/#{topic.id}/changes.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["diff_html"]).to include("<ins>corrected </ins>", "<del>An </del>")
    expect(response.parsed_body["title_diff_html"]).to include("<ins>corrected </ins>")
  end

  it "surfaces private review feedback on the working copy" do
    sign_in(admin)
    get "/t/#{topic.id}.json"
    expect(response.parsed_body["blog_publication"]).to include(
      "review_feedback_count" => 0,
      "active_review_links" => 0,
    )

    older = issue_blog_review(topic, user: admin, label: "Round one")
    newer = issue_blog_review(topic, user: admin)
    newer.update_columns(post_version: 2)
    submit_blog_review_feedback(older, name: "Ada", message: "Tighten the introduction.")
    submit_blog_review_feedback(newer, message: "Loving it but the colours hurt.")
    revoke_blog_review(older, user: admin)

    get "/t/#{topic.id}.json"
    expect(response.parsed_body["blog_publication"]).to include(
      "review_feedback_count" => 2,
      "active_review_links" => 1,
    )

    get "/blog-editor/publications/#{topic.id}/feedback.json"
    expect(response.status).to eq(200)
    feedback = response.parsed_body["feedback"]
    expect(feedback.map { |entry| entry["message"] }).to eq(
      ["Loving it but the colours hurt.", "Tighten the introduction."],
    )
    expect(feedback.last).to include("name" => "Ada")
    expect(feedback.last["review"]).to include("label" => "Round one", "post_version" => 1)
    expect(feedback.last["review"]["revoked_at"]).to be_present
    expect(response.parsed_body["more"]).to be(false)
    expect(response.parsed_body["latest_version"]).to eq(2)

    sign_in(user)
    get "/blog-editor/publications/#{topic.id}/feedback.json"
    expect(response.status).to eq(403)
  end

  it "keeps editorial state and diffs away from readers and unpublished topics" do
    publication = Blog::Publication.for_topic(topic)
    publish_blog_draft(publication, admin)
    discussion = publication.discussion_topic

    get "/t/#{discussion.id}.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body).not_to have_key("blog_publication")

    sign_in(user)
    get "/t/#{discussion.id}.json"
    expect(response.parsed_body).not_to have_key("blog_publication")
    get "/blog-editor/publications/#{topic.id}/changes.json"
    expect(response.status).to eq(403)

    sign_in(admin)
    other = Fabricate(:topic, category: drafts, user: admin)
    Fabricate(:post, topic: other, user: admin)
    get "/blog-editor/publications/#{other.id}/changes.json"
    expect(response.status).to eq(404)
  end

  it "treats a Blog-category topic without a publication as an unpublished discussion" do
    sign_in(admin)
    public_topic = Fabricate(:topic, category: category, user: admin)
    Fabricate(:post, topic: public_topic, user: admin)

    get "/t/#{public_topic.id}.json"
    expect(response.parsed_body["blog_publication"]).to include(
      "role" => "discussion",
      "status" => "draft",
      "live" => false,
      "source_url" => nil,
    )
  end

  it "reports withdrawn articles and ignores unchanged re-submissions" do
    sign_in(admin)
    publication = Blog::Publication.for_topic(topic)
    publish_blog_draft(publication, admin)

    submit_blog_draft(publication, admin)
    get "/t/#{topic.id}.json"
    expect(response.parsed_body["blog_publication"]).to include("status" => "live", "changes" => [])

    unpublish_blog_article(publication, admin)
    get "/t/#{topic.id}.json"
    expect(response.parsed_body["blog_publication"]).to include(
      "status" => "unpublished",
      "published" => false,
    )
  end

  it "reports diffs that are too large instead of failing" do
    sign_in(admin)
    publish_blog_draft(Blog::Publication.for_topic(topic), admin)
    first_post.revise(admin, raw: "A corrected article body ready for another release.")
    DiscourseDiff
      .any_instance
      .stubs(:inline_html)
      .raises(
        ONPDiff::DiffLimitExceeded.new(
          comparisons_used: 2,
          comparison_budget: 1,
          left_size: 1,
          right_size: 1,
        ),
      )

    get "/blog-editor/publications/#{topic.id}/changes.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body).to include("diff_error" => true, "diff_html" => nil)
  end
end
