# frozen_string_literal: true

RSpec.describe "Chat channel", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:sidebar_page) { PageObjects::Pages::Sidebar.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when first batch of messages doesnt fill page" do
    before { 30.times { Fabricate(:chat_message, user: current_user, chat_channel: channel_1) } }

    it "autofills for more messages" do
      chat.prefers_full_page
      visit("/")
      # cheap trick to ensure the messages don't fill the initial page
      page.execute_script(
        "document.head.insertAdjacentHTML('beforeend', `<style>.chat-message-text{font-size:3px;}</style>`)",
      )
      sidebar_page.open_channel(channel_1)

      expect(channel_page.messages).to have_message(id: message_1.id)
    end
  end

  context "when sending a message" do
    context "with lots of messages" do
      before { 50.times { Fabricate(:chat_message, chat_channel: channel_1) } }

      it "loads most recent messages" do
        unloaded_message = Fabricate(:chat_message, chat_channel: channel_1)
        chat.visit_channel(channel_1, message_id: message_1.id)

        expect(channel_page.messages).to have_no_message(id: unloaded_message.id)

        channel_page.send_message

        expect(channel_page.messages).to have_message(id: unloaded_message.id)
      end
    end

    context "with two sessions opened on same channel" do
      it "syncs the messages" do
        using_session(:tab_1) do
          sign_in(current_user)
          chat.visit_channel(channel_1)
        end

        using_session(:tab_2) do
          sign_in(current_user)
          chat.visit_channel(channel_1)
        end

        using_session(:tab_1) do |session|
          channel_page.send_message("test_message")
          session.quit
        end

        using_session(:tab_2) do |session|
          expect(channel_page).to have_message(text: "test_message")
          session.quit
        end
      end
    end

    it "allows to edit this message once persisted" do
      chat.visit_channel(channel_1)
      channel_page.send_message("aaaaaa")

      expect(channel_page.messages).to have_message(persisted: true, text: "aaaaaa")

      last_message = find(".chat-message-container:last-child")
      last_message.hover

      expect(channel_page).to have_css(
        ".chat-message-actions-container[data-id='#{last_message["data-id"]}']",
      )
    end
  end

  context "when clicking the arrow button" do
    before { 50.times { Fabricate(:chat_message, chat_channel: channel_1) } }

    it "jumps to the bottom of the channel" do
      unloaded_message = Fabricate(:chat_message, chat_channel: channel_1)
      visit("/chat/message/#{message_1.id}")

      expect(channel_page).to have_no_loading_skeleton
      expect(page).to have_no_css("[data-id='#{unloaded_message.id}']")

      find(".chat-scroll-to-bottom__button.visible").click

      expect(channel_page).to have_no_loading_skeleton
      expect(page).to have_css("[data-id='#{unloaded_message.id}']")
    end
  end

  context "when returning to a channel where last read is not last message" do
    it "jumps to the bottom of the channel" do
      channel_1.membership_for(current_user).update!(last_read_message: message_1)
      messages = 50.times.map { Fabricate(:chat_message, chat_channel: channel_1) }
      chat.visit_channel(channel_1)

      expect(page).to have_css("[data-id='#{messages.first.id}']")
      expect(page).to have_no_css("[data-id='#{messages.last.id}']")
    end
  end

  context "when a new message is created" do
    fab!(:other_user) { Fabricate(:user) }

    before do
      channel_1.add(other_user)
      50.times { Fabricate(:chat_message, chat_channel: channel_1) }
    end

    xit "doesn’t scroll the pane" do
      visit("/chat/message/#{message_1.id}")

      new_message = Fabricate(:chat_message, chat_channel: channel_1)

      expect(page).to have_no_content(new_message.message)
    end
  end

  context "when a message contains mentions" do
    fab!(:other_user) { Fabricate(:user) }
    fab!(:message) do
      Fabricate(
        :chat_message,
        chat_channel: channel_1,
        message: "hello @here @all @#{current_user.username} @#{other_user.username} @unexisting",
        user: other_user,
      )
    end

    before { channel_1.add(other_user) }

    it "highlights the mentions" do
      chat.visit_channel(channel_1)

      expect(page).to have_selector(".mention.highlighted.valid-mention", text: "@here")
      expect(page).to have_selector(".mention.highlighted.valid-mention", text: "@all")
      expect(page).to have_selector(
        ".mention.highlighted.valid-mention",
        text: "@#{current_user.username}",
      )
      expect(page).to have_selector(".mention", text: "@#{other_user.username}")
      expect(page).to have_selector(".mention", text: "@unexisting")
    end

    it "renders user status on mentions" do
      SiteSetting.enable_user_status = true
      current_user.set_status!("off to dentist", "tooth")
      other_user.set_status!("surfing", "surfing_man")
      Fabricate(:chat_mention, user: current_user, chat_message: message)
      Fabricate(:chat_mention, user: other_user, chat_message: message)

      chat.visit_channel(channel_1)

      expect(page).to have_selector(
        ".mention .user-status-message img[alt='#{current_user.user_status.emoji}']",
      )
      expect(page).to have_selector(
        ".mention .user-status-message img[alt='#{other_user.user_status.emoji}']",
      )
    end
  end

  context "when reply is right under" do
    fab!(:other_user) { Fabricate(:user) }

    before do
      Fabricate(:chat_message, in_reply_to: message_1, user: other_user, chat_channel: channel_1)
      channel_1.add(other_user)
    end

    it "doesn’t show the reply-to line" do
      chat.visit_channel(channel_1)

      expect(page).to have_no_selector(".chat-reply__excerpt")
    end
  end

  context "when reply is not directly connected" do
    fab!(:other_user) { Fabricate(:user) }

    before do
      Fabricate(:chat_message, user: other_user, chat_channel: channel_1)
      Fabricate(:chat_message, in_reply_to: message_1, user: other_user, chat_channel: channel_1)
      channel_1.add(other_user)
    end

    it "shows the reply-to line" do
      chat.visit_channel(channel_1)

      expect(page).to have_selector(".chat-reply__excerpt")
    end
  end

  context "when replying to message that has HTML tags" do
    fab!(:other_user) { Fabricate(:user) }
    fab!(:message_2) do
      Fabricate(
        :chat_message,
        user: other_user,
        chat_channel: channel_1,
        message: "<mark>not marked</mark>",
      )
    end

    before do
      Fabricate(:chat_message, user: other_user, chat_channel: channel_1)
      Fabricate(:chat_message, in_reply_to: message_2, user: current_user, chat_channel: channel_1)
      channel_1.add(other_user)
    end

    it "renders text in the reply-to" do
      chat.visit_channel(channel_1)

      expect(find(".chat-reply .chat-reply__excerpt")["innerHTML"].strip).to eq(
        "&lt;mark&gt;not marked&lt;/mark&gt;",
      )
    end

    it "renders safe HTML like mentions (which are just links) in the reply-to" do
      message_2.update!(message: "@#{other_user.username} <mark>not marked</mark>")
      message_2.rebake!
      chat.visit_channel(channel_1)

      expect(find(".chat-reply .chat-reply__excerpt")["innerHTML"].strip).to eq(
        "<a class=\"mention\" href=\"/u/#{other_user.username}\">@#{other_user.username}</a> &lt;mark&gt;not marked&lt;/mark&gt;",
      )
    end
  end

  context "when messages are separated by a day" do
    before { Fabricate(:chat_message, chat_channel: channel_1, created_at: 2.days.ago) }

    it "shows a date separator" do
      chat.visit_channel(channel_1)

      expect(page).to have_selector(".chat-message-separator__text", text: "Today")
    end
  end

  context "when a message contains code fence" do
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1, message: <<~MESSAGE) }
      Here's a message with code highlighting

      \`\`\`ruby
      Widget.triangulate(arg: "test")
      \`\`\`
      MESSAGE

    it "adds the correct lang" do
      chat.visit_channel(channel_1)

      expect(page).to have_selector("code.lang-ruby")
    end
  end

  context "when scrolling" do
    before { 50.times { Fabricate(:chat_message, chat_channel: channel_1) } }

    it "resets the active message" do
      chat.visit_channel(channel_1)
      last_message = find(".chat-message-container:last-child")
      last_message.hover

      expect(page).to have_css(
        ".chat-message-actions-container[data-id='#{last_message["data-id"]}']",
      )

      find(".chat-messages-scroll").scroll_to(0, -1000)

      expect(page).to have_no_css(
        ".chat-message-actions-container[data-id='#{last_message["data-id"]}']",
      )
    end
  end
end
