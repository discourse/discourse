# frozen_string_literal: true

RSpec.describe "Navigation", type: :system, js: true do
  fab!(:user_1) { Fabricate(:admin) }
  fab!(:category_channel_1) { Fabricate(:category_channel) }
  fab!(:category_channel_2) { Fabricate(:category_channel) }
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:chat_drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap(user_1, [category_channel_1, category_channel_2])
    sign_in(user_1)
  end

  context "when drawer is closed" do
    before { visit("/") }

    context "when pressing dash" do
      it "opens the drawer" do
        find("body").send_keys("-")

        expect(page).to have_css(".chat-drawer.is-expanded")
      end
    end
  end

  context "when drawer is opened" do
    before do
      visit("/")
      chat_page.open_from_header
    end

    context "when pressing escape" do
      it "opens the drawer" do
        expect(page).to have_css(".chat-drawer.is-expanded")

        chat_drawer_page.open_channel(category_channel_1)
        find(".chat-composer-input").send_keys(:escape)

        expect(page).to_not have_css(".chat-drawer.is-expanded")
      end
    end
  end
end
