# frozen_string_literal: true

describe "User tips" do
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
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(tooltip).to be_not_present
    end
  end

  context "when user tips are enabled" do
    before { SiteSetting.enable_user_tips = true }

    it "shows the 'first notification' tip to the user when enabled" do
      sign_in(user)

      expect(user.user_option.seen_popups).to eq(nil)

      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(tooltip).to be_present(text: "Your first notification!")

      # Find an element with no action to simulate clicking outside the user tip
      browser_root
        .locator("th.topic-list-data span")
        .filter(visible: true)
        .filter(hasText: browser_text_pattern("Topic"))
        .click

      expect(tooltip).to be_not_present
    end

    it "shows a second notification once first is dismissed and user visits a topic" do
      sign_in(user)
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      browser_root
        .locator(".fk-d-tooltip__content .user-tip__buttons .btn-primary")
        .filter(visible: true)
        .click

      expect(tooltip).to be_not_present

      discovery.topic_list.visit_topic(topics[0])

      expect(tooltip).to be_present(text: "Topic timeline")

      tooltip.locator(".user-tip__buttons .btn-primary").filter(visible: true).click

      expect(tooltip).to be_present(text: "Keep reading!")
    end

    it "can skip all tips" do
      sign_in(user)
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      tooltip
        .locator(".user-tip__buttons .btn")
        .filter(visible: true)
        .filter(hasText: browser_text_pattern("Skip tips"))
        .click

      expect(tooltip).to be_not_present

      discovery.topic_list.visit_topic(topics[0])

      expect(tooltip).to be_not_present
    end

    it "displays the labels correctly even in French (with apostrophes)" do
      SiteSetting.default_locale = :fr

      I18n.with_locale(:fr) do
        sign_in(user)
        browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(tooltip).to be_present(text: "Votre première notification !")

        tooltip
          .locator(".user-tip__buttons .btn")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern("J'ai compris !"))
          .click

        expect(tooltip).to be_not_present
      end
    end
  end
end
