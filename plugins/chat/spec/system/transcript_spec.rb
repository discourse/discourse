# frozen_string_literal: true

RSpec.describe "Quoting chat message transcripts", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:admin)
  fab!(:chat_channel_1) { Fabricate(:chat_channel) }

  let(:cdp) { PageObjects::CDP.new }
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap(admin, [chat_channel_1])
    chat_channel_1.add(current_user)
    sign_in(current_user)
  end

  def copy_messages_to_clipboard(messages)
    messages = Array.wrap(messages)
    messages.each { |message| channel_page.messages.select(message) }
    channel_page.selection_management.copy
    expect(PageObjects::Components::Toasts.new).to have_success(
      I18n.t("js.chat.quote.copy_success"),
    )
    cdp.clipboard_has_text?(generate_transcript(messages, current_user), chomp: true)
    cdp.read_clipboard
  end

  def generate_transcript(messages, acting_user)
    messages = Array.wrap(messages)
    Chat::TranscriptService
      .new(messages.first.chat_channel, acting_user, messages_or_ids: messages.map(&:id))
      .generate_markdown
      .chomp
  end

  describe "copying quote transcripts with the clipboard" do
    before { cdp.allow_clipboard }

    context "when quoting a single message into a topic" do
      fab!(:post_1) { Fabricate(:post) }
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: chat_channel_1) }

      it "quotes the message" do
        chat_page.visit_channel(chat_channel_1)

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
        clip_text = copy_messages_to_clipboard([message_1, message_2])
        topic_page.visit_topic_and_open_composer(post_1.topic)
        topic_page.fill_in_composer("This is a new post!\n\n" + clip_text)

        expect(page).to have_css(".d-editor-preview .chat-transcript", count: 2)
        expect(page).to have_content("Originally sent in #{chat_channel_1.name}")

        topic_page.send_reply

        selector = topic_page.post_by_number_selector(2)
        expect(page).to have_css("#{selector} .chat-transcript", count: 2)
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

        clip_text = copy_messages_to_clipboard(message_1)
        channel_page.selection_management.cancel
        channel_page.send_message(clip_text)

        expect(page).to have_css(".chat-message", count: 2)
        expect(page).to have_css(".chat-transcript")
      end
    end
  end

  context "when quoting into a topic directly" do
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: chat_channel_1) }
    let(:topic_title) { "Some topic title for testing" }

    it "opens the topic composer with correct state" do
      chat_page.visit_channel(chat_channel_1)
      channel_page.messages.select(message_1)
      channel_page.selection_management.quote

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

    context "when quoting from a thread" do
      fab!(:thread_1) { Fabricate(:chat_thread, channel: chat_channel_1) }

      before { chat_channel_1.update!(threading_enabled: true) }

      context "when in drawer mode" do
        before { chat_page.prefers_drawer }

        it "correctly quotes the message" do
          visit("/")
          chat_page.open_from_header
          drawer_page.open_channel(thread_1.channel)
          channel_page.reply_to(message_1)
          thread_page.messages.select(message_1)
          thread_page.selection_management.quote

          expect(topic_page).to have_composer_content(generate_transcript(message_1, current_user))
        end
      end
    end

    context "when on mobile" do
      it "first navigates to the channel's category before opening the topic composer with the quote prefilled",
         mobile: true do
        chat_page.visit_channel(chat_channel_1)
        channel_page.messages.select(message_1)
        channel_page.selection_management.quote

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
