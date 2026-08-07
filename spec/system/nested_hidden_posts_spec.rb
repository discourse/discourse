# frozen_string_literal: true

RSpec.describe "Nested view hidden posts" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }
  fab!(:hidden_reply) do
    Fabricate(
      :post,
      topic: topic,
      user: user,
      raw: "This hidden reply should be visibly muted in nested view",
      reply_to_post_number: nil,
      hidden: true,
      hidden_reason_id: Post.hidden_reasons[:flag_threshold_reached],
    )
  end

  let(:nested_view) { PageObjects::Pages::NestedView.new }

  before do
    SiteSetting.nested_replies_enabled = true
    Fabricate(:nested_topic, topic: topic)
    sign_in(admin)
  end

  it "marks hidden posts with the same hidden classes used by the flat topic view" do
    nested_view.visit_nested(topic)

    hidden_post = find(".nested-post__article[data-post-number=\"#{hidden_reply.post_number}\"]")
    hidden_post_classes = hidden_post.ancestor(".nested-post")["class"]

    expect(hidden_post_classes).to include("post-hidden")
    expect(hidden_post_classes).to include("post--hidden")
    expect(hidden_post_classes).to include("nested-post--hidden")
  end
end
