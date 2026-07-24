# frozen_string_literal: true

RSpec.describe "Post voting nested topic" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }
  fab!(:root_reply) { Fabricate(:post, topic: topic, raw: "Nested reply") }
  fab!(:nested_topic) { Fabricate(:nested_topic, topic: topic) }

  let(:nested_view) { PageObjects::Pages::NestedView.new }

  before do
    SiteSetting.nested_replies_enabled = true
    SiteSetting.post_voting_enabled = true
    sign_in(user)
  end

  it "lets the user read the topic in nested view" do
    nested_view.visit_nested(topic)

    expect(nested_view).to have_nested_view
    expect(nested_view).to have_op_post
    expect(nested_view).to have_root_post(root_reply)
  end
end
