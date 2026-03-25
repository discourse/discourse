# frozen_string_literal: true

RSpec.describe "Nested view floating actions" do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

  let(:nested_view) { PageObjects::Pages::NestedView.new }
  let(:composer) { PageObjects::Components::Composer.new }

  before { SiteSetting.nested_replies_enabled = true }

  describe "as admin" do
    before { sign_in(admin) }

    it "shows notification button, admin menu, and reply button" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_floating_actions
      expect(nested_view).to have_notification_button
      expect(nested_view).to have_admin_menu_button
      expect(nested_view).to have_floating_reply_button
    end

    it "can change notification level" do
      nested_view.visit_nested(topic)
      nested_view.change_notification_level(3) # Watching
      expect(page).to have_css(
        ".nested-view__floating-actions .notifications-tracking-trigger-btn[data-level-id='3']",
      )
    end

    it "can close and reopen a topic via admin menu" do
      nested_view.visit_nested(topic)
      nested_view.click_admin_close_topic

      nested_view.open_admin_menu
      expect(page).to have_css(".topic-admin-open")
      expect(topic.reload).to be_closed

      find(".topic-admin-open .btn").click
      nested_view.open_admin_menu
      expect(page).to have_css(".topic-admin-close")
      expect(topic.reload).not_to be_closed
    end

    it "hides floating actions when composer is open" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_floating_actions

      nested_view.click_floating_reply_button
      expect(composer).to be_opened
      expect(nested_view).to have_no_floating_actions

      composer.close
      expect(composer).to be_closed
      expect(nested_view).to have_floating_actions
    end
  end

  describe "as regular user" do
    before { sign_in(user) }

    it "shows notification button and reply button but not admin menu" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_notification_button
      expect(nested_view).to have_floating_reply_button
      expect(nested_view).to have_no_admin_menu_button
    end
  end

  describe "as anonymous user" do
    it "does not show notification button or reply button" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_no_notification_button
      expect(nested_view).to have_no_floating_reply_button
    end
  end

  describe "in context view" do
    fab!(:root_reply) { Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "Root reply") }
    fab!(:child_reply) do
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "Child reply",
        reply_to_post_number: root_reply.post_number,
      )
    end

    before { sign_in(admin) }

    it "shows floating actions in context view" do
      nested_view.visit_nested_context(topic, post_number: child_reply.post_number)
      expect(nested_view).to have_context_view
      expect(nested_view).to have_floating_actions
      expect(nested_view).to have_notification_button
      expect(nested_view).to have_admin_menu_button
      expect(nested_view).to have_floating_reply_button
    end
  end
end
