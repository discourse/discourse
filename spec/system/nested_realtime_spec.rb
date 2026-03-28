# frozen_string_literal: true

RSpec.describe "Nested view real-time updates" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:other_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }
  fab!(:root_reply) do
    Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "Existing root reply")
  end

  let(:nested_view) { PageObjects::Pages::NestedView.new }

  before do
    SiteSetting.nested_replies_enabled = true
    sign_in(user)
  end

  describe "new root post by another user" do
    it "shows new replies notification banner and loads posts on click" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_nested_view
      expect(nested_view).to have_root_post(root_reply)

      # Create a root post via PostCreator which triggers MessageBus
      PostCreator.create!(
        other_user,
        topic_id: topic.id,
        raw: "A brand new root reply from another user",
      )

      expect(page).to have_css(".nested-view__new-replies-btn", wait: 10)

      find(".nested-view__new-replies-btn").click

      expect(page).to have_no_css(".nested-view__new-replies-btn")
      expect(page).to have_content("A brand new root reply from another user")
    end
  end

  describe "new child reply by another user" do
    it "shows the new child in the tree" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_nested_view
      expect(nested_view).to have_root_post(root_reply)

      new_child =
        PostCreator.create!(
          other_user,
          topic_id: topic.id,
          reply_to_post_number: root_reply.post_number,
          raw: "A child reply via message bus",
        )

      expect(page).to have_css(
        "[data-post-number='#{new_child.post_number}']",
        text: "A child reply via message bus",
        wait: 10,
      )
    end
  end
end
