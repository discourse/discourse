# frozen_string_literal: true

RSpec.describe "Send message", type: :system do
  fab!(:user_1) { Fabricate(:admin) }
  fab!(:user_2) { Fabricate(:admin) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    # simpler user search without having to worry about user search data
    SiteSetting.enable_names = false

    chat_system_bootstrap
  end

  context "with direct message channels" do
    context "when users are not following the channel" do
      fab!(:channel_1) { Fabricate(:direct_message_channel, users: [user_1, user_2]) }

      before do
        channel_1.remove(user_1)
        channel_1.remove(user_2)
      end

      it "shows correct state" do
        using_session(:user_1) do
          sign_in(user_1)
          visit("/")

          expect(chat_page.sidebar).to have_no_direct_message_channel(channel_1)
        end

        using_session(:user_2) do
          sign_in(user_2)
          visit("/")

          expect(chat_page.sidebar).to have_no_direct_message_channel(channel_1)
        end

        using_session(:user_1) do
          chat_page.open_new_message
          chat_page.message_creator.filter(user_2.username)
          chat_page.message_creator.click_row(user_2)

          expect(chat_page.sidebar).to have_direct_message_channel(channel_1)
        end

        using_session(:user_2) do
          expect(chat_page.sidebar).to have_no_direct_message_channel(channel_1)
        end

        using_session(:user_1) do |session|
          channel_page.send_message

          expect(chat_page.sidebar).to have_direct_message_channel(channel_1)

          session.quit
        end

        using_session(:user_2) do |session|
          expect(chat_page.sidebar).to have_direct_message_channel(channel_1, mention: true)

          session.quit
        end
      end
    end

    context "when users are following the channel" do
      fab!(:channel_1) { Fabricate(:direct_message_channel, users: [user_1, user_2]) }

      it "shows correct state" do
        using_session(:user_1) do
          sign_in(user_1)
          visit("/")

          expect(chat_page.sidebar).to have_direct_message_channel(channel_1)
        end

        using_session(:user_2) do
          sign_in(user_2)
          visit("/")

          expect(chat_page.sidebar).to have_direct_message_channel(channel_1)
        end

        using_session(:user_1) do
          chat_page.open_new_message
          chat_page.message_creator.filter(user_2.username)
          chat_page.message_creator.click_row(user_2)

          expect(chat_page.sidebar).to have_direct_message_channel(channel_1)
        end

        using_session(:user_2) do
          expect(chat_page.sidebar).to have_direct_message_channel(channel_1)
        end

        using_session(:user_1) do |session|
          channel_page.send_message

          expect(chat_page.sidebar).to have_direct_message_channel(channel_1)

          session.quit
        end

        using_session(:user_2) do |session|
          expect(chat_page.sidebar).to have_direct_message_channel(channel_1, mention: true)

          session.quit
        end
      end
    end
  end
end
