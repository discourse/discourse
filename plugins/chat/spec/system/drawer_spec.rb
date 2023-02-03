# frozen_string_literal: true

RSpec.describe "Drawer", type: :system, js: true do
  fab!(:current_user) { Fabricate(:admin) }
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:drawer) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when opening" do
    it "uses stored size" do
      visit("/") # we need to visit the page first to set the local storage

      page.execute_script "window.localStorage.setItem('discourse_chat_drawer_size_width','500');"
      page.execute_script "window.localStorage.setItem('discourse_chat_drawer_size_height','500');"

      visit("/")

      chat_page.open_from_header

      expect(page.find(".chat-drawer").native.style("width")).to eq("500px")
      expect(page.find(".chat-drawer").native.style("height")).to eq("500px")
    end
  end
end
