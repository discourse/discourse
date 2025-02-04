# frozen_string_literal: true

describe "User tips", type: :system do
  fab!(:admin)
  fab!(:user)
  fab!(:topics) { Fabricate.times(2, :post).map(&:topic) }
  fab!(:posts) { Fabricate.times(3, :post, topic: topics[0]) }

  let(:discovery) { PageObjects::Pages::Discovery.new }
  let(:tooltip) { PageObjects::Components::Tooltips.new("user-tip") }

  context "when user tips are disabled" do
    before { SiteSetting.enable_user_tips = false }

    it "does not show the 'first notification' tip to the user when disabled" do
      sign_in(user)
      visit("/")

      expect(tooltip).to be_not_present
    end

    it "does not show the boostrapping tip to an admin user" do
      SiteSetting.bootstrap_mode_enabled = true
      sign_in(admin)
      visit("/")

      expect(tooltip).to be_not_present
    end
  end

  context "when user tips are enabled" do
    before { SiteSetting.enable_user_tips = true }

    it "shows the 'first notification' tip to the user when enabled" do
      sign_in(user)

      expect(user.user_option.seen_popups).to eq(nil)

      visit("/")

      expect(tooltip).to be_present(text: "Your first notification!")

      # Find an element with no action to simulate clicking outside the user tip
      find("th.topic-list-data span", text: "Topic").click

      expect(tooltip).to be_not_present
    end

    it "shows a second notification once first is dismissed and user visits a topic" do
      sign_in(user)
      visit("/")
      find(".fk-d-tooltip__content .user-tip__buttons .btn-primary").click

      expect(tooltip).to be_not_present

      discovery.topic_list.visit_topic(topics[0])

      expect(tooltip).to be_present(text: "Topic timeline")

      tooltip.find(".user-tip__buttons .btn-primary").click

      expect(tooltip).to be_present(text: "Keep reading!")
    end

    it "can skip all tips" do
      sign_in(user)
      visit("/")

      tooltip.find(".user-tip__buttons .btn", text: "Skip tips").click

      expect(tooltip).to be_not_present

      discovery.topic_list.visit_topic(topics[0])

      expect(tooltip).to be_not_present
    end
  end
end
