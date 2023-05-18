# frozen_string_literal: true

RSpec.describe "Shortcuts | drawer", type: :system, js: true do
  fab!(:user_1) { Fabricate(:admin) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:channel_2) { Fabricate(:chat_channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:drawer) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap(user_1, [channel_1, channel_2])
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
      it "closes the drawer" do
        expect(page).to have_css(".chat-drawer.is-expanded")

        drawer.open_channel(channel_1)
        find(".chat-composer__input").send_keys(:escape)

        expect(page).to have_no_css(".chat-drawer.is-expanded")
      end
    end

    context "when pressing a letter" do
      it "doesn’t intercept the event" do
        drawer.open_channel(channel_1)
        find(".header-sidebar-toggle").click # simple way to ensure composer is not focused

        page.send_keys("e")

        expect(find(".chat-composer__input").value).to eq("")
      end
    end

    context "when using Up/Down arrows" do
      it "navigates through the channels" do
        drawer.open_channel(channel_1)

        expect(page).to have_selector(".chat-drawer[data-chat-channel-id=\"#{channel_1.id}\"]")

        find(".chat-composer__input").send_keys(%i[alt arrow_down])

        expect(page).to have_selector(".chat-drawer[data-chat-channel-id=\"#{channel_2.id}\"]")

        find(".chat-composer__input").send_keys(%i[alt arrow_down])

        expect(page).to have_selector(".chat-drawer[data-chat-channel-id=\"#{channel_1.id}\"]")

        find(".chat-composer__input").send_keys(%i[alt arrow_up])

        expect(page).to have_selector(".chat-drawer[data-chat-channel-id=\"#{channel_2.id}\"]")
      end
    end
  end
end
