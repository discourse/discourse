# frozen_string_literal: true

RSpec.describe "Deleted message", type: :system, js: true do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when deleting a message" do
    it "shows as deleted" do
      chat_page.visit_channel(channel_1)
      channel_page.send_message("aaaaaaaaaaaaaaaaaaaa")
      expect(page).to have_no_css(".chat-message-staged")
      last_message = find(".chat-message-container:last-child")
      channel_page.delete_message(OpenStruct.new(id: last_message["data-id"]))

      expect(page).to have_content(I18n.t("js.chat.deleted"))
    end
  end
end
