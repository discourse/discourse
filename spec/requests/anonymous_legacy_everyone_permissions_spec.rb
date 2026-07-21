# frozen_string_literal: true

RSpec.describe "anonymous legacy everyone permissions" do
  fab!(:admin)
  fab!(:shared_drafts_category, :category)

  before { SiteSetting.granular_anonymous_and_logged_in_groups_permissions = false }

  it "does not inherit everyone permissions for sensitive visibility checks" do
    SiteSetting.delete_all_posts_and_topics_allowed_groups = Group::AUTO_GROUPS[:everyone].to_s
    first_post = Fabricate(:post)
    topic = first_post.topic
    deleted_post = Fabricate(:post, topic:, raw: "deleted post should stay private")
    PostDestroyer.new(admin, deleted_post).destroy
    deleted_post.reload

    get "/t/#{topic.slug}/#{topic.id}.json", params: { show_deleted: true }

    expect(response.status).to eq(200)
    post_ids = response.parsed_body.dig("post_stream", "posts").map { |post| post["id"] }
    expect(post_ids).not_to include(deleted_post.id)
    expect(response.body).not_to include(deleted_post.raw)

    SiteSetting.shared_drafts_category = shared_drafts_category.id
    SiteSetting.shared_drafts_allowed_groups = Group::AUTO_GROUPS[:everyone].to_s
    shared_draft_topic = Fabricate(:topic, category: shared_drafts_category)
    shared_draft_post =
      Fabricate(:post, topic: shared_draft_topic, raw: "shared draft should stay private")
    Fabricate(:shared_draft, topic: shared_draft_topic, category: Fabricate(:category))

    get "/t/#{shared_draft_topic.slug}/#{shared_draft_topic.id}.json"

    expect(response).to be_not_found
    expect(response.body).not_to include(shared_draft_post.raw)

    SiteSetting.lazy_load_categories_groups = Group::AUTO_GROUPS[:everyone].to_s

    get "/site.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["lazy_load_categories"]).to eq(true)
  end
end
