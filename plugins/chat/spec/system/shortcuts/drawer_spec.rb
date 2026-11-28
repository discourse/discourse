# frozen_string_literal: true

RSpec.describe "Shortcuts | drawer" do
  fab!(:user_1, :admin)
  fab!(:channel_1, :chat_channel)
  fab!(:channel_2, :chat_channel)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }
  let(:lightbox) { PageObjects::Components::PhotoSwipe.new }

  before do
    chat_system_bootstrap(user_1, [channel_1, channel_2])
    sign_in(user_1)
  end

  context "when drawer is closed" do
    before { visit("/") }

    context "when pressing dash" do
      it "opens the drawer" do
        page.send_keys("-")

        expect(chat_page).to have_drawer
      end
    end
  end

  context "when drawer is opened" do
    before do
      visit("/")
      chat_page.open_from_header
    end

    context "when pressing escape" do
      it "leaves unfocused typing alone, then blurs and closes the drawer on Escape" do
        expect(chat_page).to have_drawer

        drawer_page.open_channel(channel_1)
        page.send_keys(:tab) # move focus out of the composer before testing letter interception
        page.send_keys("e")
        expect(channel_page.composer.value).to eq("")

        channel_page.composer.input.click
        expect(channel_page.composer).to be_focused

        page.send_keys(:escape)

        expect(page).to have_no_css(".chat-drawer .chat-composer__input:focus")
        expect(chat_page).to have_drawer

        page.send_keys(:escape)

        expect(chat_page).to have_no_drawer
      end

      context "when lightbox is open" do
        fab!(:upload)
        fab!(:message) do
          Fabricate(:chat_message, chat_channel: channel_1, upload_ids: [upload.id])
        end

        it "does not close the drawer" do
          expect(chat_page).to have_drawer

          drawer_page.open_channel(channel_1)
          find(".chat-img-upload").click

          expect(lightbox).to be_visible

          page.send_keys(:escape)

          expect(lightbox).to be_hidden
          expect(chat_page).to have_drawer
        end
      end
    end

    context "when using Up/Down arrows" do
      it "navigates through the channels" do
        drawer_page.open_channel(channel_1)

        expect(chat_page).to have_drawer(channel_id: channel_1.id)

        page.send_keys(%i[alt down])

        expect(chat_page).to have_drawer(channel_id: channel_2.id)

        page.send_keys(%i[alt down])

        expect(chat_page).to have_drawer(channel_id: channel_1.id)

        page.send_keys(%i[alt up])

        expect(chat_page).to have_drawer(channel_id: channel_2.id)
      end
    end
  end
end
