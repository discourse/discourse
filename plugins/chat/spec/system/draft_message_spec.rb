# frozen_string_literal: true

RSpec.describe "Draft message", type: :system, js: true do
  fab!(:current_user) { Fabricate(:admin) }
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:drawer) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when current user never interacted with other user" do
    fab!(:user) { Fabricate(:user) }

    it "opens channel info page" do
      visit("/chat/draft-channel")
      expect(page).to have_selector(".results")

      find(".results .user:nth-child(1)").click

      expect(channel_page).to have_no_loading_skeleton
    end
  end
end
