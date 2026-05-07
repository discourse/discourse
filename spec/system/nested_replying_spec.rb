# frozen_string_literal: true

RSpec.describe "Nested view replying" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

  let(:nested_view) { PageObjects::Pages::NestedView.new }
  let(:composer) { PageObjects::Components::Composer.new }

  before do
    SiteSetting.nested_replies_enabled = true
    sign_in(user)
  end

  describe "replying to a nested post" do
    fab!(:root_reply) do
      Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "Root reply to discuss")
    end

    it "stays on nested view after replying" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_nested_view

      nested_view.click_reply_on_post(root_reply)
      expect(composer).to be_opened

      composer.fill_content("This is my nested reply")
      composer.submit

      expect(composer).to be_closed
      expect(nested_view).to have_nested_view
      expect(page).to have_current_path(%r{/n/})
    end
  end

  describe "replying to the OP" do
    it "stays on nested view after replying" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_nested_view

      nested_view.click_reply_on_op
      expect(composer).to be_opened

      composer.fill_content("This is a reply to the original post")
      composer.submit

      expect(composer).to be_closed
      expect(nested_view).to have_nested_view
      expect(page).to have_current_path(%r{/n/})
    end
  end

  describe "floating reply button" do
    it "is visible for logged-in users" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_floating_reply_button
    end

    it "is not visible for anonymous users" do
      Capybara.reset_sessions!
      nested_view.visit_nested(topic)
      expect(nested_view).to have_no_floating_reply_button
    end

    it "opens the composer for a top-level reply" do
      nested_view.visit_nested(topic)
      nested_view.click_floating_reply_button
      expect(composer).to be_opened

      composer.fill_content("A top-level reply via floating button")
      composer.submit
      expect(composer).to be_closed

      expect(nested_view).to have_nested_view
      expect(page).to have_current_path(%r{/n/})
    end

    it "hides when the composer is open and reappears when closed" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_floating_reply_button

      nested_view.click_floating_reply_button
      expect(composer).to be_opened
      expect(nested_view).to have_no_floating_reply_button

      composer.close
      expect(composer).to be_closed
      expect(nested_view).to have_floating_reply_button
    end
  end

  describe "replying to a collapsed post" do
    fab!(:root_reply) do
      Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "Root reply with children")
    end

    fab!(:child_reply) do
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "Child reply",
        reply_to_post_number: root_reply.post_number,
      )
    end

    it "auto-expands a collapsed post after submitting a reply" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_children_visible_for(root_reply)

      nested_view.click_reply_on_post(root_reply)
      expect(composer).to be_opened

      nested_view.click_depth_line(root_reply)
      expect(nested_view).to have_collapsed_bar_for(root_reply)

      composer.fill_content("Reply to collapsed post")
      composer.submit
      expect(composer).to be_closed

      expect(nested_view).to have_no_collapsed_bar_for(root_reply)
      expect(nested_view).to have_children_visible_for(root_reply)
    end
  end

  describe "replying to a post with no existing children" do
    fab!(:root_reply) do
      Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "Post with no children yet")
    end

    it "shows the depth line on the parent without refresh" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_no_depth_line_for(root_reply)

      nested_view.click_reply_on_post(root_reply)
      composer.fill_content("First child reply")
      composer.submit
      expect(composer).to be_closed

      expect(nested_view).to have_depth_line_for(root_reply)
    end
  end

  describe "replying to a leaf post" do
    fab!(:root_reply) { Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "Root reply") }

    fab!(:child_reply) do
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "Child reply (leaf)",
        reply_to_post_number: root_reply.post_number,
      )
    end

    it "shows the new reply as a child" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_post(child_reply)

      nested_view.click_reply_on_post(child_reply)
      expect(composer).to be_opened

      composer.fill_content("Reply to leaf post")
      composer.submit
      expect(composer).to be_closed

      expect(nested_view).to have_children_visible_for(child_reply)
    end
  end
end
