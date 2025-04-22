# frozen_string_literal: true

RSpec.describe "Chat composer", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
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

  context "when adding an emoji through the picker" do
    xit "adds the emoji to the composer" do
      chat_page.visit_channel(channel_1)
      channel_page.open_action_menu
      channel_page.click_action_button("emoji")
      find("[data-emoji='grimacing']").click(wait: 0.5)

      expect(channel_page.composer).to have_value(":grimacing:")
    end

    it "removes denied emojis from insert emoji picker" do
      SiteSetting.emoji_deny_list = "monkey|peach"

      chat_page.visit_channel(channel_1)
      channel_page.composer.open_emoji_picker

      expect(page).to have_no_selector("[data-emoji='monkey']")
      expect(page).to have_no_selector("[data-emoji='peach']")
    end
  end

  context "when adding an emoji through the autocomplete" do
    it "adds the emoji to the composer" do
      chat_page.visit_channel(channel_1)
      find(".chat-composer__input").send_keys(":gri")
      find(".emoji-shortname", text: "grimacing").click

      expect(channel_page.composer).to have_value(":grimacing: ")
    end

    it "doesn't suggest denied emojis and aliases" do
      SiteSetting.emoji_deny_list = "peach|poop"
      chat_page.visit_channel(channel_1)

      find(".chat-composer__input").fill_in(with: ":peac")
      expect(page).to have_no_selector(".emoji-shortname", text: "peach")

      find(".chat-composer__input").fill_in(with: ":hank") # alias
      expect(page).to have_no_selector(".emoji-shortname", text: "poop")
    end
  end

  context "when opening emoji picker through more button of the autocomplete" do
    xit "prefills the emoji picker filter input" do
      chat_page.visit_channel(channel_1)
      find(".chat-composer__input").fill_in(with: ":gri")

      click_link(I18n.t("js.composer.more_emoji"))

      expect(find(".emoji-picker .filter-input")).to have_value("gri")
    end

    xit "filters with the prefilled input" do
      chat_page.visit_channel(channel_1)
      find(".chat-composer__input").fill_in(with: ":fr")

      click_link(I18n.t("js.composer.more_emoji"))

      expect(page).to have_selector(".emoji-picker [data-emoji='fr']")
      expect(page).to have_no_selector(".emoji-picker [data-emoji='grinning']")
    end

    xit "replaces the partially typed emoji with the selected" do
      chat_page.visit_channel(channel_1)
      find(".chat-composer__input").fill_in(with: "hey :gri")

      click_link(I18n.t("js.composer.more_emoji"))
      find("[data-emoji='grimacing']").click(wait: 0.5)

      expect(channel_page.composer).to have_value("hey :grimacing:")
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
      before { current_user.user_option.update!(chat_send_shortcut: 0) }

      context "when pressing enter" do
        it "sends the message" do
          chat_page.visit_channel(channel_1)

          channel_page.composer.send_keys("testenter")
          channel_page.composer.enter_shortcut

          expect(channel_page.messages).to have_message(text: "testenter")
        end
      end

      context "when pressing shift + enter" do
        it "adds a linebreak" do
          chat_page.visit_channel(channel_1)

          channel_page.composer.send_keys("testenter")
          channel_page.composer.shift_enter_shortcut

          expect(channel_page.composer).to have_value("testenter\n")
        end
      end

      context "when pressing meta + enter" do
        it "sends the message" do
          chat_page.visit_channel(channel_1)

          channel_page.composer.send_keys("testenter")
          channel_page.composer.meta_enter_shortcut

          expect(channel_page.messages).to have_message(text: "testenter")
        end
      end
    end

    context "when user preference is set to send on meta + enter" do
      before { current_user.user_option.update!(chat_send_shortcut: 1) }

      context "when pressing enter" do
        it "adds a linebreak" do
          chat_page.visit_channel(channel_1)

          channel_page.composer.send_keys("testenter")
          channel_page.composer.enter_shortcut

          expect(channel_page.composer).to have_value("testenter\n")
        end
      end

      context "when pressing shift + enter" do
        it "adds a linebreak" do
          chat_page.visit_channel(channel_1)

          channel_page.composer.send_keys("testenter")
          channel_page.composer.shift_enter_shortcut

          expect(channel_page.composer).to have_value("testenter\n")
        end
      end

      context "when pressing meta + enter" do
        it "sends the message" do
          chat_page.visit_channel(channel_1)

          channel_page.composer.send_keys("testenter")
          channel_page.composer.meta_enter_shortcut

          expect(channel_page.messages).to have_message(text: "testenter")
        end
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

      it "doesnt delete the message" do
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

    it "works" do
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
      cdp.with_slow_upload do
        attach_file(file_path) do
          channel_page.open_action_menu
          channel_page.click_action_button("chat-upload-btn")
        end

        expect(page).to have_css(".chat-composer-upload--in-progress")
        expect(page).to have_css(".chat-composer.is-send-disabled")
        page.find(".chat-composer-upload").hover
        page.find(".chat-composer-upload__remove-btn").click
      end
    end
  end

  context "when sending a react message" do
    fab!(:react_message) do
      Fabricate(:chat_message, user: current_user, chat_channel: channel_1, message: "HI!")
    end

    context "in a channel" do
      it "adds a reaction to the message" do
        chat_page.visit_channel(channel_1)

        channel_page.send_message("+:+1:")

        expect(channel_page).to have_reaction(react_message, "+1")
      end

      it "works with literal emoji" do
        chat_page.visit_channel(channel_1)

        channel_page.send_message("+👍")

        expect(channel_page).to have_reaction(react_message, "+1")
      end
    end

    context "in a thread" do
      fab!(:original_message) do
        Fabricate(:chat_message, chat_channel: channel_1, user: current_user)
      end
      fab!(:thread) do
        Fabricate(:chat_thread, channel: channel_1, original_message: original_message)
      end

      fab!(:thread_message) do
        Fabricate(
          :chat_message,
          in_reply_to_id: original_message.id,
          chat_channel: channel_1,
          thread_id: thread.id,
          user: current_user,
        )
      end

      before do
        channel_1.update!(threading_enabled: true)
        Chat::Thread.update_counts
        thread.add(current_user)
      end

      it "adds a reaction to the message" do
        chat_page.visit_channel(channel_1)
        channel_page.message_thread_indicator(original_message).click

        expect(side_panel).to have_open_thread(original_message.thread)

        open_thread.send_message("+:+1:")

        expect(open_thread).to have_reaction(thread_message, "+1")
      end

      it "works with literal emoji" do
        chat_page.visit_channel(channel_1)
        channel_page.message_thread_indicator(original_message).click

        expect(side_panel).to have_open_thread(original_message.thread)

        open_thread.send_message("+👍")

        expect(open_thread).to have_reaction(thread_message, "+1")
      end
    end
  end
end
