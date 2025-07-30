# frozen_string_literal: true

RSpec.describe "Shortcuts | full page", type: :system do
  fab!(:channel_1, :chat_channel)
  fab!(:current_user, :user)

  let(:chat) { PageObjects::Pages::Chat.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when pressing a letter" do
    it "intercepts the event and propagates it to the composer" do
      chat.visit_channel(channel_1)
      find(".header-sidebar-toggle").click # simple way to ensure composer is not focused

      page.send_keys("e")

      expect(page).to have_field("channel-composer", with: "e")
    end
  end
end
