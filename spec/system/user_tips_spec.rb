# frozen_string_literal: true

describe "Homepage", type: :system do
  fab!(:admin)
  fab!(:user)
  fab!(:topics) { Fabricate.times(2, :post).map(&:topic) }
  fab!(:posts) { Fabricate.times(3, :post, topic: topics[0]) }
  let(:discovery) { PageObjects::Pages::Discovery.new }

  context "when user tips are disabled" do
    before { SiteSetting.enable_user_tips = false }

    it "does not show the 'first notification' tip to the user when disabled" do
      sign_in user
      visit "/"

      expect(page).to have_no_css(".fk-d-tooltip__content .user-tip__title")
    end

    it "does not show the boostrapping tip to an admin user" do
      SiteSetting.bootstrap_mode_enabled = true
      sign_in admin
      visit "/"

      expect(page).to have_no_css(".fk-d-tooltip__content .user-tip__title")
    end
  end

  context "when user tips are enabled" do
    before { SiteSetting.enable_user_tips = true }

    it "shows the 'first notification' tip to the user when enabled" do
      sign_in user
      expect(user.user_option.seen_popups).to eq(nil)

      visit "/"

      expect(page).to have_css(
        ".fk-d-tooltip__content .user-tip__title",
        text: "Your first notification!",
      )

      find(".d-header").click

      # Clicking outside element dismisses the tip
      expect(page).to have_no_css(
        ".fk-d-tooltip__content .user-tip__title",
        text: "Your first notification!",
      )

      page.refresh

      expect(page).to have_no_css(
        ".fk-d-tooltip__content .user-tip__title",
        text: "Your first notification!",
      )
    end

    it "shows a second notification once first is dismissed and user visits a topic" do
      sign_in user
      visit "/"

      find(".fk-d-tooltip__content .user-tip__buttons .btn-primary").click
      expect(page).to have_no_css(".fk-d-tooltip__content .user-tip__title")

      discovery.topic_list.visit_topic(topics[0])
      expect(page).to have_css(".fk-d-tooltip__content .user-tip__title", text: "Topic timeline")

      find(".fk-d-tooltip__content .user-tip__buttons .btn-primary").click
      expect(page).to have_css(".fk-d-tooltip__content .user-tip__title", text: "Keep reading!")
    end

    it "can skip all tips" do
      sign_in user
      visit "/"

      find(".fk-d-tooltip__content .user-tip__buttons .btn", text: "Skip tips").click
      expect(page).to have_no_css(".fk-d-tooltip__content .user-tip__title")

      discovery.topic_list.visit_topic(topics[0])
      expect(page).to have_no_css(".fk-d-tooltip__content .user-tip__title")
    end
  end
end
