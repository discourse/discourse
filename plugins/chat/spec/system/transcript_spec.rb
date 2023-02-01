# frozen_string_literal: true

RSpec.describe "Quoting chat message transcripts", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:chat_channel_1) { Fabricate(:chat_channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:chat_channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    chat_system_bootstrap(Fabricate(:admin), [chat_channel_1])
    chat_channel_1.add(current_user)
    sign_in(current_user)
  end

  def select_message_desktop(message)
    if page.has_css?(".chat-message-container.selecting-messages")
      chat_channel_page.message_by_id(message.id).find(".chat-message-selector").click
    else
      chat_channel_page.message_by_id(message.id).hover
      expect(page).to have_css(".chat-message-actions .more-buttons")
      find(".chat-message-actions .more-buttons").click
      find(".select-kit-row[data-value=\"selectMessage\"]").click
    end
  end

  def select_message_mobile(message)
    if page.has_css?(".chat-message-container.selecting-messages")
      chat_channel_page.message_by_id(message.id).find(".chat-message-selector").click
    else
      chat_channel_page.message_by_id(message.id).click(delay: 0.5)
      find(".chat-message-action-item[data-id=\"selectMessage\"]", wait: 5).click
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
        "chat-quote-btn"
      when "copy"
        "chat-copy-btn"
      when "cancel"
        "chat-cancel-selection-btn"
      when "move"
        "chat-move-to-channel-btn"
      end
    find_button(selector, disabled: false, wait: 5).click
  end

  def copy_messages_to_clipboard(messages)
    messages = Array.wrap(messages)
    messages.each { |message| select_message_desktop(message) }
    expect(chat_channel_page).to have_selection_management
    click_selection_button("copy")
    expect(page).to have_selector(".chat-copy-success")
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

    context "when quoting a single message into a topic" do
      fab!(:post_1) { Fabricate(:post) }
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: chat_channel_1) }

      it "quotes the message" do
        chat_page.visit_channel(chat_channel_1)

        expect(chat_channel_page).to have_no_loading_skeleton

        clip_text = copy_messages_to_clipboard(message_1)
        topic_page.visit_topic_and_open_composer(post_1.topic)
        topic_page.fill_in_composer("This is a new post!\n\n" + clip_text)

        within(".d-editor-preview") { expect(page).to have_css(".chat-transcript") }

        topic_page.send_reply
        selector = topic_page.post_by_number_selector(2)

        expect(page).to have_css(selector)
        within(selector) { expect(page).to have_css(".chat-transcript") }
      end
    end

    context "when quoting multiple messages into a topic" do
      fab!(:post_1) { Fabricate(:post) }
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: chat_channel_1) }
      fab!(:message_2) { Fabricate(:chat_message, chat_channel: chat_channel_1) }

      it "quotes the messages" do
        chat_page.visit_channel(chat_channel_1)

        expect(chat_channel_page).to have_no_loading_skeleton

        clip_text = copy_messages_to_clipboard([message_1, message_2])
        topic_page.visit_topic_and_open_composer(post_1.topic)
        topic_page.fill_in_composer("This is a new post!\n\n" + clip_text)

        within(".d-editor-preview") { expect(page).to have_css(".chat-transcript", count: 2) }
        expect(page).to have_content("Originally sent in #{chat_channel_1.name}")

        topic_page.send_reply

        selector = topic_page.post_by_number_selector(2)
        expect(page).to have_css(selector)
        within(selector) { expect(page).to have_css(".chat-transcript", count: 2) }
      end
    end

    context "when quoting a message containing a onebox" do
      fab!(:post_1) { Fabricate(:post) }
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: chat_channel_1) }

      before do
        Oneboxer.stubs(:preview).returns(
          "<aside class=\"onebox\"><article class=\"onebox-body\"><h3><a href=\"http://www.example.com/article.html\" tabindex=\"-1\">An interesting article</a></h3></article></aside>",
        )
        message_1.update!(message: "http://www.example.com/has-title.html")
        message_1.rebake!
      end

      it "works" do
        chat_page.visit_channel(chat_channel_1)

        expect(chat_channel_page).to have_no_loading_skeleton

        clip_text = copy_messages_to_clipboard(message_1)
        topic_page.visit_topic_and_open_composer(post_1.topic)
        topic_page.fill_in_composer(clip_text)

        within(".chat-transcript-messages") do
          expect(page).to have_content("An interesting article")
        end
      end
    end

    context "when quoting a message in another message" do
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: chat_channel_1) }

      it "quotes the message" do
        chat_page.visit_channel(chat_channel_1)

        expect(chat_channel_page).to have_no_loading_skeleton

        clip_text = copy_messages_to_clipboard(message_1)
        click_selection_button("cancel")
        chat_channel_page.send_message(clip_text)

        expect(page).to have_selector(".chat-message", count: 2)

        message = ChatMessage.find_by(user: current_user, message: clip_text.chomp)

        within(chat_channel_page.message_by_id(message.id)) do
          expect(page).to have_css(".chat-transcript")
        end
      end
    end
  end

  context "when quoting into a topic directly" do
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: chat_channel_1) }
    let(:topic_title) { "Some topic title for testing" }

    it "opens the topic composer with correct state" do
      chat_page.visit_channel(chat_channel_1)

      expect(chat_channel_page).to have_no_loading_skeleton

      select_message_desktop(message_1)
      click_selection_button("quote")

      expect(topic_page).to have_expanded_composer
      expect(topic_page).to have_composer_content(generate_transcript(message_1, current_user))
      expect(page).to have_css(
        ".category-input .select-kit-header[data-value='#{chat_channel_1.chatable.id}']",
      )
      expect(page).not_to have_current_path(chat_channel_1.chatable.url)

      topic_page.fill_in_composer_title(topic_title)
      topic_page.send_reply

      selector = topic_page.post_by_number_selector(1)
      expect(page).to have_css(selector)
      within(selector) { expect(page).to have_css(".chat-transcript") }

      topic = Topic.find_by(user: current_user, title: topic_title)
      expect(page).to have_current_path(topic.url)
    end

    context "when on mobile" do
      it "first navigates to the channel's category before opening the topic composer with the quote prefilled",
         mobile: true do
        chat_page.visit_channel(chat_channel_1)
        expect(chat_channel_page).to have_no_loading_skeleton

        select_message_mobile(message_1)
        click_selection_button("quote")

        expect(topic_page).to have_expanded_composer
        expect(topic_page).to have_composer_content(generate_transcript(message_1, current_user))
        expect(page).to have_current_path(chat_channel_1.chatable.url)
        expect(page).to have_css(
          ".category-input .select-kit-header[data-value='#{chat_channel_1.chatable.id}']",
        )
      end
    end
  end
end
