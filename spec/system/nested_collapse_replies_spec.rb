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
    Fabricate(:nested_topic, topic: topic)
    sign_in(op_user)
  end

  context "in the root view" do
    it "renders all descendants by default" do
      nested_view.visit_nested(topic)

      expect(nested_view).to have_post(root_post)
      expect(nested_view).to have_post(reply_to_root)
      expect(nested_view).to have_post(reply_to_reply)
    end

    it "hides the root post's replies entirely when collapse_replies=true" do
      page.visit("/n/#{topic.slug}/#{topic.id}?collapse_replies=true")

      # Roots are the focal level — visible.
      expect(nested_view).to have_post(root_post)

      # Their replies (depth 1+) are hidden behind an "Expand X replies"
      # button on the root, so the user can scan only the new roots.
      expect(nested_view).to have_no_post(reply_to_root)
      expect(nested_view).to have_no_post(reply_to_reply)
    end
  end

  context "in the context view" do
    it "renders direct replies but hides grandchildren when collapse_replies=true" do
      page.visit("/n/#{topic.slug}/#{topic.id}/#{root_post.post_number}?collapse_replies=true")

      expect(nested_view).to have_context_view

      # Chain root and its direct replies (the "new content") are visible.
      expect(nested_view).to have_post(root_post)
      expect(nested_view).to have_post(reply_to_root)

      # Grandchildren of the chain root are collapsed behind an "Expand"
      # button on the depth-1 reply.
      expect(nested_view).to have_no_post(reply_to_reply)
    end
  end
end
