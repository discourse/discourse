# frozen_string_literal: true

RSpec.describe "Quoting chat message transcripts", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:chat_channel_1) { Fabricate(:chat_channel) }
  fab!(:chat_message_1) { Fabricate(:chat_message, chat_channel: chat_channel_1) }
  fab!(:chat_message_2) { Fabricate(:chat_message, chat_channel: chat_channel_1) }
  fab!(:chat_message_3) { Fabricate(:chat_message, chat_channel: chat_channel_1) }
  fab!(:chat_message_4) { Fabricate(:chat_message, chat_channel: chat_channel_1) }
  fab!(:chat_message_5) { Fabricate(:chat_message, chat_channel: chat_channel_1) }
  fab!(:topic) { Fabricate(:with_posts_topic) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:chat_channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    chat_system_bootstrap(current_user, [chat_channel_1])
    sign_in(current_user)
  end

  def select_message(message, mobile: false)
    if page.has_css?(".chat-message-container.selecting-messages")
      chat_channel_page.message_by_id(message.id).find(".chat-message-selector").click
    else
      # we long press instead of hover on mobile
      if mobile
        chat_channel_page.message_by_id(message.id).click(delay: 0.5)
      else
        chat_channel_page.message_by_id(message.id).hover
      end

      # we also have a different actions menu on mobile
      if mobile
        find(".chat-message-action-item[data-id=\"selectMessage\"]").click
      else
        expect(page).to have_css(".chat-message-actions .more-buttons")
        find(".chat-message-actions .more-buttons").click
        find(".select-kit-row[data-value=\"selectMessage\"]").click
      end
    end
  end

  def cdp_allow_clipboard_access!
    cdp_params = {
      origin: page.server_url,
      permission: {
        name: "clipboard-read",
      },
      setting: "granted",
    }
    page.driver.browser.execute_cdp("Browser.setPermission", **cdp_params)

    cdp_params = {
      origin: page.server_url,
      permission: {
        name: "clipboard-write",
      },
      setting: "granted",
    }
    page.driver.browser.execute_cdp("Browser.setPermission", **cdp_params)
  end

  def read_clipboard
    page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")
  end

  def click_selection_button(button)
    selector =
      case button
      when "quote"
        "#chat-quote-btn"
      when "copy"
        "#chat-copy-btn"
      when "cancel"
        "#chat-cancel-selection-btn"
      when "move"
        "#chat-move-to-channel-btn"
      end
    within(".chat-selection-management-buttons") { find(selector).click }
  end

  def copy_messages_to_clipboard(messages)
    messages = Array.wrap(messages)
    messages.each { |message| select_message(message) }
    expect(chat_channel_page).to have_selection_management
    click_selection_button("copy")
    expect(page).to have_content("Chat quote copied to clipboard")
    clip_text = read_clipboard
    expect(clip_text.chomp).to eq(generate_transcript(messages, current_user))
    clip_text
  end

  def generate_transcript(messages, acting_user)
    messages = Array.wrap(messages)
    ChatTranscriptService
      .new(messages.first.chat_channel, acting_user, messages_or_ids: messages.map(&:id))
      .generate_markdown
      .chomp
  end

  describe "copying quote transcripts with the clipboard" do
    before { cdp_allow_clipboard_access! }

    it "quotes a single chat message into a topic " do
      chat_page.visit_channel(chat_channel_1)
      expect(chat_channel_page).to have_no_loading_skeleton
      expect(chat_channel_page).to have_content(chat_message_5.message)

      clip_text = copy_messages_to_clipboard(chat_message_5)

      # post transcript in topic
      topic_page.visit_topic_and_open_composer(topic)
      topic_page.fill_in_composer("This is a new post!\n\n" + clip_text)
      within ".d-editor-preview" do
        expect(page).to have_css(".chat-transcript")
      end
      topic_page.send_reply
      expect(page).to have_content("This is a new post!")
      within topic_page.post_by_number(topic.posts.reload.last.post_number) do
        expect(page).to have_css(".chat-transcript")
      end
    end

    it "quotes multiple chat messages into a topic" do
      chat_page.visit_channel(chat_channel_1)
      expect(chat_channel_page).to have_no_loading_skeleton
      expect(chat_channel_page).to have_content(chat_message_5.message)

      messages = [chat_message_5, chat_message_4, chat_message_3, chat_message_2]
      clip_text = copy_messages_to_clipboard(messages)

      # post transcript in topic
      topic_page.visit_topic_and_open_composer(topic)
      topic_page.fill_in_composer("This is a new post!\n\n" + clip_text)
      within ".d-editor-preview" do
        expect(page).to have_css(".chat-transcript", count: 4)
      end
      expect(page).to have_content("Originally sent in #{chat_channel_1.name}")
      topic_page.send_reply
      expect(page).to have_content("This is a new post!")
      within topic_page.post_by_number(topic.posts.reload.last.post_number) do
        expect(page).to have_css(".chat-transcript", count: 4)
      end
    end

    it "does not error in preview when quoting a chat message with a onebox" do
      Oneboxer.stubs(:preview).returns(
        "<aside class=\"onebox\"><article class=\"onebox-body\"><h3><a href=\"http://www.example.com/article.html\" tabindex=\"-1\">An interesting article</a></h3></article></aside>",
      )
      chat_message_3.update!(message: "http://www.example.com/has-title.html")
      chat_message_3.rebake!

      chat_page.visit_channel(chat_channel_1)
      expect(chat_channel_page).to have_no_loading_skeleton
      expect(chat_channel_page).to have_content(chat_message_5.message)

      clip_text = copy_messages_to_clipboard(chat_message_3)

      # post transcript in topic
      topic_page.visit_topic_and_open_composer(topic)
      topic_page.fill_in_composer(clip_text)

      within ".chat-transcript-messages" do
        expect(page).to have_content("An interesting article")
      end
    end

    it "quotes a single chat message into another chat message " do
      chat_page.visit_channel(chat_channel_1)
      expect(chat_channel_page).to have_no_loading_skeleton
      expect(chat_channel_page).to have_content(chat_message_5.message)

      # select message + copy to clipboard
      clip_text = copy_messages_to_clipboard(chat_message_5)
      click_selection_button("cancel")

      # send transcript message in chat
      chat_channel_page.fill_composer(clip_text)
      chat_channel_page.click_send_message
      message = nil
      try_until_success do
        message = ChatMessage.find_by(user: current_user, message: clip_text.chomp)
        expect(message).not_to eq(nil)
      end
      expect(chat_channel_page).to have_message(id: message.id)
      within chat_channel_page.message_by_id(message.id) do
        expect(page).to have_css(".chat-transcript")
      end
    end
  end

  describe "quoting into a topic directly" do
    it "opens the topic composer with the quote prefilled and the channel category preselected" do
      topic.update!(category: chat_channel_1.chatable)
      chat_page.visit_channel(chat_channel_1)
      expect(chat_channel_page).to have_no_loading_skeleton
      expect(chat_channel_page).to have_content(chat_message_5.message)

      # select message + prefill in composer
      select_message(chat_message_5)
      click_selection_button("quote")
      expect(topic_page).to have_expanded_composer
      expect(topic_page).to have_composer_content(generate_transcript(chat_message_5, current_user))
      expect(page).to have_css(
        ".category-input .select-kit-header[data-value='#{chat_channel_1.chatable.id}']",
      )
      expect(page).not_to have_current_path(chat_channel_1.chatable.url)

      # create the topic with the transcript as the OP
      topic_page.fill_in_composer_title("Some topic title for testing")
      topic_page.send_reply
      expect(page).to have_content("Some topic title for testing")
      topic = Topic.where(user: current_user).last
      expect(page).to have_current_path(topic.url)
      within topic_page.post_by_number(1) do
        expect(page).to have_css(".chat-transcript")
      end

      # ensure the transcript date is formatted
      expect(page).to have_css(".chat-transcript-datetime a[data-date-formatted=\"true\"]")
    end

    context "when on mobile" do
      it "first navigates to the channel's category before opening the topic composer with the quote prefilled",
         mobile: true do
        topic.update!(category: chat_channel_1.chatable)
        chat_page.visit_channel(chat_channel_1)
        expect(chat_channel_page).to have_no_loading_skeleton
        expect(chat_channel_page).to have_content(chat_message_5.message)

        # select message + prefill in composer
        select_message(chat_message_5, mobile: true)
        click_selection_button("quote")

        expect(topic_page).to have_expanded_composer
        expect(topic_page).to have_composer_content(
          generate_transcript(chat_message_5, current_user),
        )
        expect(page).to have_current_path(chat_channel_1.chatable.url)
        expect(page).to have_css(
          ".category-input .select-kit-header[data-value='#{chat_channel_1.chatable.id}']",
        )
      end
    end
  end
end
