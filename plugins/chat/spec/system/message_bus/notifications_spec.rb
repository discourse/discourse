# frozen_string_literal: true

RSpec.describe "Chat MessageBus | notifications", type: :system do
  fab!(:current_user, :user)
  fab!(:other_user, :user)
  fab!(:channel, :category_channel)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:sidebar_page) { PageObjects::Pages::ChatSidebar.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap(current_user, [channel])
    channel.add(other_user)
  end

  describe "new_mentions" do
    it "increments mention count in sidebar when a user is mentioned" do
      Jobs.run_immediately!

      sign_in(current_user)
      other_channel = Fabricate(:category_channel)
      other_channel.add(current_user)
      chat_page.visit_channel(other_channel)

      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: other_user,
        message: "hey @#{current_user.username} check this out",
        use_service: true,
      )

      expect(sidebar_page).to have_unread_channel(channel)
    end
  end
end
