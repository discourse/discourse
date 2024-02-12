# frozen_string_literal: true

RSpec.describe "List channels | mobile", type: :system, mobile: true do
  fab!(:current_user) { Fabricate(:user) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when channels present" do
    context "when category channels" do
      fab!(:category_channel_1) { Fabricate(:category_channel) }

      it "doesn’t show the last message" do
        message =
          Fabricate(
            :chat_message,
            chat_channel: category_channel_1,
            user: current_user,
            use_service: true,
          )

        visit("/chat/direct-messages")

        expect(page).to have_no_selector(".chat-channel__last-message", text: message.message)
      end

      context "when member of the channel" do
        before { category_channel_1.add(current_user) }

        it "shows the channel in the correct section" do
          visit("/chat/channels")
          expect(page.find(".public-channels")).to have_content(category_channel_1.name)
        end
      end

      context "when not member of the channel" do
        it "doesn’t show the channel" do
          visit("/chat/channels")

          expect(page.find(".public-channels", visible: :all)).to have_no_content(
            category_channel_1.name,
          )
        end
      end
    end

    context "when multiple category channels are present" do
      fab!(:channel_1) { Fabricate(:category_channel, name: "a channel") }
      fab!(:channel_2) { Fabricate(:category_channel, name: "b channel") }
      fab!(:channel_3) { Fabricate(:category_channel, name: "c channel") }
      fab!(:channel_4) { Fabricate(:category_channel, name: "d channel") }

      before do
        channel_1.add(current_user)
        channel_2.add(current_user)
        channel_3.add(current_user)
        channel_4.add(current_user)
      end

      it "sorts them by mentions, unread, then alphabetical order" do
        Jobs.run_immediately!

        Fabricate(
          :chat_message,
          chat_channel: channel_1,
          created_at: 10.minutes.ago,
          use_service: true,
        )
        Fabricate(
          :chat_message,
          chat_channel: channel_2,
          created_at: 5.minutes.ago,
          use_service: true,
        )
        Fabricate(
          :chat_message_with_service,
          chat_channel: channel_4,
          message: "Hey @#{current_user.username}",
          user: Fabricate(:user),
        )

        Fabricate(:chat_message, chat_channel: channel_3, user: current_user, use_service: true)

        visit("/chat/channels")

        # channel with mentions should be first
        expect(page.find("#public-channels a:nth-child(1)")["data-chat-channel-id"]).to eq(
          channel_4.id.to_s,
        )
        # channels with unread messages are next, sorted by title
        expect(page.find("#public-channels a:nth-child(2)")["data-chat-channel-id"]).to eq(
          channel_1.id.to_s,
        )
        expect(page.find("#public-channels a:nth-child(3)")["data-chat-channel-id"]).to eq(
          channel_2.id.to_s,
        )
      end
    end

    context "when direct message channels" do
      fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }
      fab!(:inaccessible_dm_channel_1) { Fabricate(:direct_message_channel) }

      it "show the last message" do
        message =
          Fabricate(
            :chat_message,
            chat_channel: dm_channel_1,
            user: current_user,
            use_service: true,
          )

        visit("/chat/direct-messages")

        expect(page).to have_selector(".chat-channel__last-message", text: message.message)
      end

      context "when member of the channel" do
        it "shows the channel in the correct section" do
          visit("/chat/direct-messages")
          expect(page.find(".direct-message-channels")).to have_content(current_user.username)
        end
      end

      context "when not member of the channel" do
        it "doesn’t show the channel" do
          visit("/chat")
          expect(page).to have_no_content(inaccessible_dm_channel_1.title(current_user))
        end
      end
    end
  end

  context "when no category channels" do
    it "hides the section" do
      visit("/chat/channels")

      expect(page).to have_no_css(".channels-list-container")
    end

    context "when user can create channels" do
      before { current_user.update!(admin: true) }

      it "shows the section" do
        visit("/chat/channels")
        expect(page).to have_css(".channels-list-container")
      end
    end
  end

  context "when no direct message channels" do
    it "shows the section" do
      visit("/chat/direct-messages")
      expect(page).to have_selector(".channels-list-container")
    end
  end

  context "when chat disabled" do
    before { SiteSetting.chat_enabled = false }

    it "doesn’t show the sections" do
      visit("/chat")
      expect(page).to have_no_css(".public-channels-section")
      expect(page).to have_no_css(".direct-message-channels-section")
    end
  end

  context "when user has chat disabled" do
    before do
      SiteSetting.chat_enabled = false
      current_user.user_option.update!(chat_enabled: false)
    end

    it "doesn’t show the sections" do
      visit("/chat")
      expect(page).to have_no_css(".public-channels-section")
      expect(page).to have_no_css(".direct-message-channels-section")
    end
  end

  it "has a new dm channel button" do
    visit("/chat/direct-messages")
    find(".c-navbar__new-dm-button").click

    expect(chat.message_creator).to be_opened
  end
end
