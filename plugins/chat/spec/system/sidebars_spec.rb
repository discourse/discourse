# frozen_string_literal: true

RSpec.describe "Navigation", type: :system, js: true do
  fab!(:category) { Fabricate(:category) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:user) { Fabricate(:admin) }
  fab!(:category_channel) { Fabricate(:category_channel) }
  fab!(:category_channel_2) { Fabricate(:category_channel) }
  let(:chat_page) { PageObjects::Pages::Chat.new }

  before do
    chat_system_bootstrap(user, [category_channel, category_channel_2])
    sign_in(user)
  end

  context "when core sidebar is enabled" do
    before do
      SiteSetting.enable_sidebar = true
      SiteSetting.enable_experimental_sidebar_hamburger = true
    end

    it "uses core sidebar" do
      visit("/chat")

      expect(page).to have_css("#d-sidebar")
      expect(page).to_not have_css(".channels-list")
    end

    context "when visiting on mobile" do
      it "has no sidebar" do
        visit("/?mobile_view=1")
        chat_page.visit_channel(category_channel_2)

        expect(page).to_not have_css("#d-sidebar")
      end
    end
  end

  it "uses chat sidebar" do
    visit("/chat")

    expect(page).to have_css(".channels-list")
    expect(page).to_not have_css("#d-sidebar")
  end

  context "when visiting on mobile" do
    it "has no sidebar" do
      visit("/?mobile_view=1")
      chat_page.visit_channel(category_channel_2)

      expect(page).to_not have_css(".channels-list")
    end
  end
end
