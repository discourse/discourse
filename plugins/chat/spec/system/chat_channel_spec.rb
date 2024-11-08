# frozen_string_literal: true

RSpec.describe "Chat channel", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:message_1) { Fabricate(:chat_message, use_service: true, chat_channel: channel_1) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:sidebar_page) { PageObjects::Pages::Sidebar.new }
  let(:side_panel_page) { PageObjects::Pages::ChatSidePanel.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when has unread threads" do
    fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1) }

    before do
      channel_1.update!(threading_enabled: true)
      thread_1.add(current_user)
      Fabricate(:chat_message, thread: thread_1, use_service: true)
    end

    context "when visiting channel" do
      it "opens thread panel" do
        chat_page.visit_channel(channel_1)

        expect(side_panel_page).to have_open_thread_list
      end
    end

    context "when visiting channel on mobile", mobile: true do
      it "doesn’t open  thread panel" do
        chat_page.visit_channel(channel_1)

        expect(side_panel_page).to have_no_open_thread_list
      end
    end

    context "when visiting thread" do
      it "doesn’t open thread panel" do
        chat_page.visit_thread(thread_1)

        expect(side_panel_page).to have_no_open_thread_list
      end
    end

    context "when opening channel message" do
      it "doesn’t open  thread panel" do
        chat_page.visit_channel(channel_1, message_id: message_1.id)

        expect(side_panel_page).to have_no_open_thread_list
      end
    end
  end

  context "when first batch of messages doesnt fill page" do
    before { Fabricate.times(30, :chat_message, user: current_user, chat_channel: channel_1) }

    it "autofills for more messages" do
      chat_page.prefers_full_page
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
      before { Fabricate.times(50, :chat_message, chat_channel: channel_1) }

      it "loads most recent messages" do
        unloaded_message = Fabricate(:chat_message, chat_channel: channel_1)
        chat_page.visit_channel(channel_1, message_id: message_1.id)

        expect(channel_page.messages).to have_no_message(id: unloaded_message.id)

        channel_page.send_message

        expect(channel_page.messages).to have_message(id: unloaded_message.id)
      end
    end

    context "with two sessions opened on same channel" do
      it "syncs the messages" do
        Jobs.run_immediately!

        using_session(:tab_1) do
          sign_in(current_user)
          chat_page.visit_channel(channel_1)
        end

        using_session(:tab_2) do
          sign_in(current_user)
          chat_page.visit_channel(channel_1)
        end

        using_session(:tab_1) { channel_page.send_message("test_message") }

        using_session(:tab_2) do
          expect(channel_page.messages).to have_message(text: "test_message")
        end
      end
    end

    it "allows to edit this message once persisted" do
      chat_page.visit_channel(channel_1)
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
    before { Fabricate.times(50, :chat_message, chat_channel: channel_1) }

    it "jumps to the bottom of the channel" do
      unloaded_message = Fabricate(:chat_message, chat_channel: channel_1)
      visit("/chat/c/-/#{channel_1.id}/#{message_1.id}")

      expect(channel_page).to have_no_loading_skeleton
      expect(page).to have_no_css("[data-id='#{unloaded_message.id}']")

      find(".chat-scroll-to-bottom__button.visible").click

      expect(channel_page).to have_no_loading_skeleton
      expect(page).to have_css("[data-id='#{unloaded_message.id}']")
      expect(page).to have_css(".-last-read[data-id='#{unloaded_message.id}']")
    end
  end

  context "when returning to a channel where last read is not last message" do
    it "scrolls to the correct last read message" do
      channel_1.membership_for(current_user).update!(last_read_message: message_1)
      messages = Fabricate.times(50, :chat_message, chat_channel: channel_1)
      chat_page.visit_channel(channel_1)

      expect(page).to have_css("[data-id='#{messages.first.id}']")
      expect(page).to have_no_css("[data-id='#{messages.last.id}']")
    end
  end

  context "when a new message is created" do
    before { Fabricate.times(50, :chat_message, chat_channel: channel_1) }

    it "doesn’t append the message when not at bottom" do
      visit("/chat/c/-/#{channel_1.id}/#{message_1.id}")

      expect(page).to have_css(".chat-scroll-to-bottom__button.visible")

      new_message = Fabricate(:chat_message, chat_channel: channel_1, use_service: true)

      expect(channel_page.messages).to have_no_message(id: new_message.id)
    end
  end

  context "when a message contains mentions" do
    fab!(:other_user) { Fabricate(:user) }
    fab!(:message) do
      Fabricate(
        :chat_message,
        chat_channel: channel_1,
        message:
          "hello @here @all @#{current_user.username} @#{other_user.username} @unexisting @system",
        user: other_user,
      )
    end

    before do
      SiteSetting.enable_user_status = true
      current_user.set_status!("off to dentist", "tooth")
      other_user.set_status!("surfing", "surfing_man")
      channel_1.add(other_user)
    end

    it "highlights the mentions" do
      chat_page.visit_channel(channel_1)

      expect(page).to have_selector(".mention.--wide", text: "@here")
      expect(page).to have_selector(".mention.--wide", text: "@all")
      expect(page).to have_selector(".mention.--current", text: "@#{current_user.username}")
      expect(page).to have_selector(".mention", text: "@#{other_user.username}")
      expect(page).to have_selector(".mention", text: "@unexisting")
      expect(page).to have_selector(".mention.--bot", text: "@system")
    end

    it "renders user status on mentions" do
      Fabricate(:user_chat_mention, user: current_user, chat_message: message)
      Fabricate(:user_chat_mention, user: other_user, chat_message: message)

      chat_page.visit_channel(channel_1)

      expect(page).to have_selector(
        ".mention .user-status-message img[alt='#{current_user.user_status.emoji}']",
      )
      expect(page).to have_selector(
        ".mention .user-status-message img[alt='#{other_user.user_status.emoji}']",
      )
    end

    it "renders user status when expanding collapsed message" do
      message_1 =
        Fabricate(
          :chat_message,
          chat_channel: channel_1,
          message: "hello @#{other_user.username}",
          user: current_user,
        )
      chat_page.visit_channel(channel_1)

      channel_page.messages.delete(message_1)
      channel_page.messages.restore(message_1)

      expect(page).to have_selector(
        ".chat-message-container[data-id=\"#{message_1.id}\"] .mention .user-status-message img[alt='#{other_user.user_status.emoji}']",
      )

      other_user.set_status!("hello", "heart")

      expect(page).to have_selector(
        ".chat-message-container[data-id=\"#{message_1.id}\"] .mention .user-status-message img[alt='#{other_user.user_status.emoji}']",
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
      chat_page.visit_channel(channel_1)

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
      chat_page.visit_channel(channel_1)

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
        use_service: true,
        message: "<abbr>not abbr</abbr>",
      )
    end

    before do
      Fabricate(:chat_message, user: other_user, chat_channel: channel_1)
      Fabricate(:chat_message, in_reply_to: message_2, user: current_user, chat_channel: channel_1)
      channel_1.add(other_user)

      stub_request(:get, "https://foo.com/").with(headers: { "Accept" => "*/*" }).to_return(
        status: 200,
        body: "",
        headers: {
        },
      )

      stub_request(:head, "https://foo.com/").with(headers: { "Host" => "foo.com" }).to_return(
        status: 200,
        body: "",
        headers: {
        },
      )
    end

    it "renders text in the reply-to" do
      chat_page.visit_channel(channel_1)

      expect(find(".chat-reply .chat-reply__excerpt")["innerHTML"].strip).to eq(
        "&lt;abbr&gt;not abbr&lt;/abbr&gt;",
      )
    end

    it "renders escaped HTML when including a #" do
      update_message!(message_2, user: other_user, text: "#general <abbr>not abbr</abbr>")
      chat_page.visit_channel(channel_1)

      expect(find(".chat-reply .chat-reply__excerpt")["innerHTML"].strip).to eq(
        "#general &lt;abbr&gt;not abbr&lt;/abbr&gt;",
      )
    end

    it "limits excerpt length" do
      update_message!(message_2, user: other_user, text: ("a" * 160))
      chat_page.visit_channel(channel_1)

      expect(find(".chat-reply .chat-reply__excerpt")["innerHTML"].strip).to eq("a" * 150 + "…")
    end

    it "renders urls correclty in excerpts" do
      update_message!(message_2, user: other_user, text: "https://foo.com")
      chat_page.visit_channel(channel_1)

      expect(find(".chat-reply .chat-reply__excerpt")["innerHTML"].strip).to eq("https://foo.com")
    end

    it "renders safe HTML like mentions (which are just links) in the reply-to" do
      update_message!(
        message_2,
        user: other_user,
        text: "@#{other_user.username} <abbr>not abbr</abbr>",
      )
      chat_page.visit_channel(channel_1)

      expect(find(".chat-reply .chat-reply__excerpt")["innerHTML"].strip).to eq(
        "@#{other_user.username} &lt;abbr&gt;not abbr&lt;/abbr&gt;",
      )
    end
  end

  context "when messages are separated by a day" do
    before { Fabricate(:chat_message, chat_channel: channel_1, created_at: 2.days.ago) }

    it "shows a date separator" do
      chat_page.visit_channel(channel_1)

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
      chat_page.visit_channel(channel_1)

      expect(page).to have_selector("code.lang-ruby")
    end
  end

  context "when scrolling" do
    before { 50.times { Fabricate(:chat_message, chat_channel: channel_1) } }

    it "resets the active message" do
      chat_page.visit_channel(channel_1)
      last_message = find(".chat-message-container:last-child")
      last_message.hover

      expect(page).to have_css(
        ".chat-message-actions-container[data-id='#{last_message["data-id"]}']",
      )

      find(".chat-messages-scroller").scroll_to(0, -1000)

      expect(page).to have_no_css(
        ".chat-message-actions-container[data-id='#{last_message["data-id"]}']",
      )
    end
  end

  context "when opening message secondary options" do
    it "doesn’t hide dropdown on mouseleave" do
      chat_page.visit_channel(channel_1)
      last_message = find(".chat-message-container:last-child")
      last_message.hover

      expect(page).to have_css(
        ".chat-message-actions-container[data-id='#{last_message["data-id"]}']",
      )

      find(".chat-message-actions-container .secondary-actions").click
      expect(page).to have_css(
        ".chat-message-actions-container .secondary-actions .select-kit-body",
      )

      PageObjects::Components::Logo.hover
      expect(page).to have_css(
        ".chat-message-actions-container .secondary-actions .select-kit-body",
      )

      find("#site-logo").click
      expect(page).to have_no_css(
        ".chat-message-actions-container .secondary-actions .select-kit-body",
      )
    end
  end

  it "renders emojis in page title" do
    channel_1.update!(name: ":dog: Dogs")
    chat_page.visit_channel(channel_1)

    expect(page).to have_title("#🐶 Dogs - Chat - Discourse")
  end
end
