# frozen_string_literal: true

RSpec.describe "Shortcuts | sidebar", type: :system, js: true do
  fab!(:current_user) { Fabricate(:admin) }

  let(:chat) { PageObjects::Pages::Chat.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when using Up/Down arrows" do
    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }

    before { channel_1.add(current_user) }

    context "when on homepage" do
      it "does nothing" do
        visit("/")
        find("body").send_keys(%i[alt arrow_down])

        expect(page).to have_no_selector(".channel-#{channel_1.id}.active")
        expect(page).to have_no_selector(".channel-#{dm_channel_1.id}.active")
      end
    end

    context "when on chat page" do
      it "navigates through the channels" do
        chat.visit_channel(channel_1)

        expect(page).to have_selector(".channel-#{channel_1.id}.active")

        find("body").send_keys(%i[alt arrow_down])

        expect(page).to have_selector(".channel-#{dm_channel_1.id}.active")

        find("body").send_keys(%i[alt arrow_down])

        expect(page).to have_selector(".channel-#{channel_1.id}.active")

        find("body").send_keys(%i[alt arrow_up])

        expect(page).to have_selector(".channel-#{dm_channel_1.id}.active")
      end
    end
  end
end
