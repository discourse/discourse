# frozen_string_literal: true

describe "Topic Admin Menu" do
  fab!(:admin)
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before { sign_in(admin) }

  context "when topic reply approval is enabled" do
    fab!(:post)

    before { SiteSetting.enable_topic_reply_approval = true }

    it "lets staff turn reply approval on and off from the topic menu" do
      topic_page.visit_topic(post.topic)
      topic_page.click_admin_menu_button
      find(
        ".topic-admin-reply-approval button",
        text: I18n.t("js.topic.actions.require_reply_approval"),
      ).click

      topic_page.click_admin_menu_button
      expect(page).to have_css(
        ".topic-admin-reply-approval button",
        text: I18n.t("js.topic.actions.stop_requiring_reply_approval"),
      )
      expect(post.topic.reload).to be_reply_approval_required

      find(".topic-admin-reply-approval button").click
      topic_page.click_admin_menu_button
      expect(page).to have_css(
        ".topic-admin-reply-approval button",
        text: I18n.t("js.topic.actions.require_reply_approval"),
      )
      expect(post.topic.reload).not_to be_reply_approval_required
    end
  end

  context "for a PM" do
    fab!(:pm) { Fabricate(:private_message_topic, title: "Can you help me with this?") }
    fab!(:op) { Fabricate(:post, topic: pm, user: admin, created_at: 1.day.ago) }
    fab!(:category)

    it "shows the errors when converting to a public topic is not possible" do
      # create a topic with the same title to force a "duplicate title" error
      Fabricate(:topic, title: pm.title, category: category)

      topic_page.visit_topic(pm)
      topic_page.move_to_public_category(category)
      expect(topic_page.move_to_public_modal).to have_css("#modal-alert")
    end
  end
end
