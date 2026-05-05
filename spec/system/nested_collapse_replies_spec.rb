# frozen_string_literal: true

RSpec.describe "Nested view collapse_replies URL param" do
  fab!(:op_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:replier_a) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:replier_b) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:replier_c) { Fabricate(:user, refresh_auto_groups: true) }

  fab!(:topic) { Fabricate(:topic, user: op_user) }
  fab!(:op_post) { Fabricate(:post, topic: topic, user: op_user, post_number: 1) }
  fab!(:root_post) do
    Fabricate(:post, topic: topic, user: replier_a, post_number: 2, reply_to_post_number: nil)
  end
  fab!(:reply_to_root) do
    Fabricate(:post, topic: topic, user: replier_b, post_number: 3, reply_to_post_number: 2)
  end
  fab!(:reply_to_reply) do
    Fabricate(:post, topic: topic, user: replier_c, post_number: 4, reply_to_post_number: 3)
  end

  let(:nested_view) { PageObjects::Pages::NestedView.new }

  before do
    SiteSetting.nested_replies_enabled = true
    NestedTopic.find_or_create_by!(topic: topic)
    sign_in(op_user)
  end

  it "renders all descendants by default" do
    nested_view.visit_nested(topic)

    expect(nested_view).to have_post(root_post)
    expect(nested_view).to have_post(reply_to_root)
    expect(nested_view).to have_post(reply_to_reply)
  end

  it "starts replies-of-replies collapsed when collapse_replies=1 is set" do
    page.visit("/n/#{topic.slug}/#{topic.id}?collapse_replies=true")

    # The root reply (depth 0) and its direct reply (depth 1) are still
    # rendered — that's the focal level the user is here to catch up on.
    expect(nested_view).to have_post(root_post)
    expect(nested_view).to have_post(reply_to_root)

    # Grandchildren (depth 2+) start collapsed and are not in the DOM
    # until the user expands the depth-1 post.
    expect(nested_view).to have_no_post(reply_to_reply)
  end
end
