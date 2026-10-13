# frozen_string_literal: true

RSpec.describe "Submission check HTTP response" do
  fab!(:admin)
  fab!(:author) { Fabricate(:user, trust_level: 0, refresh_auto_groups: true) }
  fab!(:owner, :user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic_with_op, category: category, user: owner) }

  before do
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger",
                     "trigger:before_post_submission",
                     configuration: {
                       "category_ids" => [category.id],
                     }
        builder.node "reject",
                     "action:reject_submission",
                     configuration: {
                       "message" => "Please wait before replying to this topic.",
                     }
        builder.connect "trigger", "reject"
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    sign_in(author)
  end

  it "returns 422 and the fixed message without creating a reply or reviewable" do
    raw = "Draft content that should remain in the composer"
    post "/posts.json", params: { topic_id: topic.id, raw: raw }

    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"].join).to include(
      "Please wait before replying to this topic.",
    )
    expect(Post.where(topic: topic, raw: raw)).not_to exist
    expect(ReviewableQueuedPost.where(target_created_by: author)).not_to exist
  end

  it "does not disclose private topic content to unauthorized users" do
    private_topic = Fabricate(:private_message_topic, user: owner)
    post "/posts.json",
         params: {
           topic_id: private_topic.id,
           raw: "Do not allow me into this private message",
         }

    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"].join).not_to include(
      "Please wait before replying to this topic.",
    )
  end
end
