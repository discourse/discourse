# frozen_string_literal: true

RSpec.describe "Receiving message", type: :system, js: true do
  fab!(:current_user) { Fabricate(:admin) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:user_3) { Fabricate(:user) }
  fab!(:direct_message_channel_1) do
    Fabricate(:direct_message_channel, users: [current_user, user_2])
  end
  fab!(:direct_message_channel_2) do
    Fabricate(:direct_message_channel, users: [current_user, user_2, user_3])
  end

  let(:chat_page) { PageObjects::Pages::Chat.new }

  before do
    chat_system_bootstrap(current_user, [direct_message_channel_1, direct_message_channel_2])
    sign_in(current_user)
  end

  context "when core sidebar is enabled" do
    before do
      SiteSetting.enable_sidebar = true
      SiteSetting.enable_experimental_sidebar_hamburger = true
    end

    context "when receiving a direct message" do
      it "reorders the direct messages sidebar section links ordering by last message received" do
        visit("/")

        expect(
          page.find(
            "#sidebar-section-content-chat-dms .sidebar-section-link-wrapper:nth-child(2) .sidebar-row",
          ),
        ).to have_content(direct_message_channel_2.name)

        creator =
          Chat::ChatMessageCreator.create(
            chat_channel: direct_message_channel_2,
            user: user_2,
            content: "this is good",
          )

        expect(
          page.find(
            "#sidebar-section-content-chat-dms .sidebar-section-link-wrapper:nth-child(1) .sidebar-row",
          ),
        ).to have_content(direct_message_channel_2.name)
      end
    end
  end
end
