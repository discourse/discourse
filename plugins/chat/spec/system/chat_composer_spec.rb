# frozen_string_literal: true

RSpec.describe "Chat composer" do
  fab!(:current_user, :user)
  fab!(:channel_1, :chat_channel)
  fab!(:message_1) { Fabricate(:chat_message, user: current_user, chat_channel: channel_1) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:cdp) { PageObjects::CDP.new }
  let(:side_panel) { PageObjects::Pages::ChatSidePanel.new }
  let(:open_thread) { PageObjects::Pages::ChatThread.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  it "inserts an emoji from the default picker and autocomplete" do
    chat_page.visit_channel(channel_1)
    composer = channel_page.composer

    composer.open_emoji_picker
    find(".emoji-picker [data-emoji='grimacing']").click
    expect(composer).to have_value(":grimacing:")

    composer.fill_in(with: "")
    composer.send_keys(":gri")
    find(".emoji-shortname", text: "grimacing").click
    expect(composer).to have_value(":grimacing: ")
  end

  it "removes denied emojis from the picker" do
    SiteSetting.emoji_deny_list = "monkey|peach"

    chat_page.visit_channel(channel_1)
    channel_page.composer.open_emoji_picker

    expect(page).to have_no_selector("[data-emoji='monkey']")
    expect(page).to have_no_selector("[data-emoji='peach']")
  end

  it "doesn't autocomplete denied emojis or their aliases" do
    SiteSetting.emoji_deny_list = "peach|poop"
    chat_page.visit_channel(channel_1)

    find(".chat-composer__input").fill_in(with: ":peac")
    expect(page).to have_no_selector(".emoji-shortname", text: "peach")

    find(".chat-composer__input").fill_in(with: ":hank") # alias
    expect(page).to have_no_selector(".emoji-shortname", text: "poop")
  end

  context "when opening emoji picker through more button of the autocomplete" do
    it "prefills and filters the picker before replacing the partial emoji" do
      chat_page.visit_channel(channel_1)
      channel_page.composer.send_keys("hey :gri")

      click_link(I18n.t("js.composer.more_emoji"))

      expect(page).to have_field(class: "filter-input", with: "gri")
      expect(page).to have_css(".emoji-picker__section.filtered [data-emoji='grimacing']")

      find(".emoji-picker [data-emoji='grimacing']").click

      expect(channel_page.composer).to have_value("hey :grimacing: ")
    end

    it "replaces a partially typed term containing Unicode letters" do
      chat_page.visit_channel(channel_1)
      input = find(".chat-composer__input")
      input.send_keys(":gri")
      # Inject a Unicode character into the partial term while the autocomplete
      # is open, so the captured term spans non-ASCII letters too.
      page.execute_script(<<~JS)
        const el = document.querySelector(".chat-composer__input");
        el.focus();
        el.setSelectionRange(el.value.length, el.value.length);
        document.execCommand("insertText", false, "ü");
      JS

      click_link(I18n.t("js.composer.more_emoji"))
      find(".emoji-picker [data-emoji='grimacing']").click

      expect(channel_page.composer).to have_value(":grimacing: ")
    end
  end

  context "when typing on keyboard" do
    it "propagates keys to composer" do
      chat_page.visit_channel(channel_1)

      find("body").send_keys("b")

      expect(channel_page.composer).to have_value("b")

      find("body").send_keys("b")

      expect(channel_page.composer).to have_value("bb")

      find("body").send_keys(:enter)

      expect(channel_page.messages).to have_message(text: "bb")
    end

    context "when user preference is set to send on enter" do
      before { current_user.user_option.update!(send_shortcut: "enter") }

      it "sends with Enter or Meta+Enter and adds a newline with Shift+Enter" do
        chat_page.visit_channel(channel_1)
        composer = channel_page.composer

        composer.send_keys("shift enter")
        composer.shift_enter_shortcut
        expect(composer).to have_value("shift enter\n")

        composer.fill_in(with: "ordinary enter")
        composer.enter_shortcut
        expect(channel_page.messages).to have_message(text: "ordinary enter")
        expect(composer).to be_blank

        composer.send_keys("meta enter")
        composer.meta_enter_shortcut
        expect(channel_page.messages).to have_message(text: "meta enter")
      end
    end

    context "when user preference is set to send on meta + enter" do
      before { current_user.user_option.update!(send_shortcut: "meta_enter") }

      it "adds a newline with Enter or Shift+Enter and sends with Meta+Enter" do
        chat_page.visit_channel(channel_1)
        composer = channel_page.composer

        composer.send_keys("ordinary enter")
        composer.enter_shortcut
        expect(composer).to have_value("ordinary enter\n")

        composer.fill_in(with: "shift enter")
        composer.shift_enter_shortcut
        expect(composer).to have_value("shift enter\n")

        composer.fill_in(with: "meta enter")
        composer.meta_enter_shortcut
        expect(channel_page.messages).to have_message(text: "meta enter")
      end
    end
  end

  context "when editing a message with no length" do
    it "deletes the message" do
      chat_page.visit_channel(channel_1)
      channel_page.composer.edit_last_message_shortcut
      channel_page.composer.fill_in(with: "")
      channel_page.click_send_message

      expect(channel_page.messages).to have_message(deleted: 1)
    end

    context "with uploads" do
      fab!(:upload_reference) do
        Fabricate(
          :upload_reference,
          target: message_1,
          upload: Fabricate(:upload, user: current_user),
        )
      end

      it "doesn't delete the message" do
        chat_page.visit_channel(channel_1)
        channel_page.composer.edit_last_message_shortcut
        channel_page.composer.send_keys("")
        channel_page.click_send_message

        expect(channel_page.messages).to have_message(id: message_1.id)
      end
    end
  end

  context "when posting a message with length equal to minimum length" do
    before { SiteSetting.chat_minimum_message_length = 1 }

    it "sends the minimum-length message" do
      chat_page.visit_channel(channel_1)
      channel_page.send_message("1")

      expect(channel_page.messages).to have_message(text: "1")
    end
  end

  context "when posting a message with length superior to minimum length" do
    before { SiteSetting.chat_minimum_message_length = 2 }

    it "doesn’t allow to send" do
      chat_page.visit_channel(channel_1)
      find("body").send_keys("1")

      expect(page).to have_css(".chat-composer.is-send-disabled")
    end
  end

  context "when upload is in progress" do
    it "doesn’t allow to send" do
      chat_page.visit_channel(channel_1)

      file_path = file_from_fixtures("logo.png", "images").path
      # Hold the upload request in-flight, without throttling everything.
      cdp.with_pending_requests(%r{/uploads\.json}) do
        attach_file("channel-file-uploader", file_path, make_visible: true)
        expect(page).to have_css(".chat-composer-upload--in-progress")
        expect(page).to have_css(".chat-composer.is-send-disabled")
        find(".chat-composer-upload").hover
        find(".chat-composer-upload__remove-btn").click
      end
    end
  end

  context "when sending a react message" do
    fab!(:react_message) do
      Fabricate(:chat_message, user: current_user, chat_channel: channel_1, message: "HI!")
    end

    context "in a channel" do
      it "adds a reaction to the last message using an emoji shortcode or literal emoji" do
        chat_page.visit_channel(channel_1)

        channel_page.send_message("+:+1:")
        expect(channel_page).to have_reaction(react_message, "+1")
        expect(channel_page.composer).to be_blank

        channel_page.click_reaction(react_message, "+1")
        expect(channel_page).to have_no_reactions(react_message)

        channel_page.send_message("+👍")
        expect(channel_page).to have_reaction(react_message, "+1")
      end
    end

    context "in a thread" do
      fab!(:original_message) do
        Fabricate(:chat_message, chat_channel: channel_1, user: current_user)
      end
      fab!(:thread) do
        chat_thread_with_replies(
          channel: channel_1,
          original_message: original_message,
          reply_users: [current_user],
          link_replies: true,
        )
      end
      let(:thread_message) { thread.replies.first }

      before { channel_1.update!(threading_enabled: true) }

      it "adds a reaction to the last thread reply using a shortcode or literal emoji" do
        chat_page.visit_channel(channel_1)
        channel_page.message_thread_indicator(original_message).click
        expect(side_panel).to have_open_thread(original_message.thread)

        open_thread.send_message("+:+1:")
        expect(open_thread).to have_reaction(thread_message, "+1")
        expect(open_thread.composer).to be_blank

        open_thread.message_reactions_list(thread_message).find('[data-emoji-name="+1"]').click
        expect(open_thread.message_by_id(thread_message.id)).to have_no_css(
          ".chat-message-reaction-list",
        )

        open_thread.send_message("+👍")
        expect(open_thread).to have_reaction(thread_message, "+1")
      end
    end
  end

  context "when using user autocomplete" do
    fab!(:autocomplete_user) do
      Fabricate(:user, username: "ac_test_user", name: "Autocomplete Test User")
    end

    before do
      SiteSetting.enable_mentions = true
      channel_1.add(autocomplete_user)
    end

    it "fails on subsequent autocomplete selection due to cache pollution" do
      chat_page.visit_channel(channel_1)

      find(".chat-composer__input").send_keys("@#{autocomplete_user.username}")
      find(".autocomplete.ac-user", text: "ac_test_user").click
      expect(channel_page.composer).to have_value("@#{autocomplete_user.username} ")
      find(".chat-composer__input").set("")

      # 2nd autocomplete attempt to ensure user object is not mutated by existing store record behaviour
      find(".chat-composer__input").send_keys("@#{autocomplete_user.username}")
      find(".autocomplete.ac-user", text: "ac_test_user").click
      expect(channel_page.composer).to have_value("@#{autocomplete_user.username} ")
    end
  end
end
