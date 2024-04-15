# frozen_string_literal: true

RSpec.describe "Deleted channel", type: :system do
  fab!(:channel_1) { Fabricate(:chat_channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }

  before do
    chat_system_bootstrap
    channel_1.destroy!
    sign_in(Fabricate(:user))
  end

  context "when visiting deleted channel" do
    it "redirects to homepage" do
      chat_page.visit_channel(channel_1)

      expect(page).to have_content("Not Found") # this is not a translated key
    end
  end
end
