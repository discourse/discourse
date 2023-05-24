# frozen_string_literal: true

RSpec.describe "Chat composer", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before { chat_system_bootstrap }

  context "when replying to a message" do
    before do
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "adds the reply indicator to the composer" do
      chat_page.visit_channel(channel_1)
      channel_page.reply_to(message_1)

      expect(page).to have_selector(
        ".chat-composer-message-details .chat-reply__username",
        text: message_1.user.username,
      )
    end

    context "with HTML tags" do
      before { message_1.update!(message: "<mark>not marked</mark>") }

      it "renders text in the details" do
        chat_page.visit_channel(channel_1)
        channel_page.reply_to(message_1)

        expect(
          find(".chat-composer-message-details .chat-reply__excerpt")["innerHTML"].strip,
        ).to eq("not marked")
      end
    end
  end

  context "when editing a message" do
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }

    before do
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "adds the edit indicator" do
      chat_page.visit_channel(channel_1)
      channel_page.edit_message(message_2)

      expect(page).to have_selector(
        ".chat-composer-message-details .chat-reply__username",
        text: current_user.username,
      )
      expect(channel_page.composer.value).to eq(message_2.message)
    end

    it "updates the message instantly" do
      chat_page.visit_channel(channel_1)
      page.driver.browser.network_conditions = { offline: true }

      channel_page.edit_message(message_2)
      find(".chat-composer__input").send_keys("instant")
      channel_page.click_send_message

      expect(channel_page).to have_message(text: message_2.message + "instant")
      page.driver.browser.network_conditions = { offline: false }
    end

    context "when pressing escape" do
      it "cancels editing" do
        chat_page.visit_channel(channel_1)
        channel_page.edit_message(message_2)
        find(".chat-composer__input").send_keys(:escape)

        expect(page).to have_no_selector(".chat-composer-message-details .chat-reply__username")
        expect(channel_page.composer.value).to eq("")
      end
    end

    context "when closing edited message" do
      it "cancels editing" do
        chat_page.visit_channel(channel_1)
        channel_page.edit_message(message_2)
        find(".cancel-message-action").click

        expect(page).to have_no_selector(".chat-composer-message-details .chat-reply__username")
        expect(channel_page.composer.value).to eq("")
      end
    end
  end

  context "when adding an emoji through the picker" do
    before do
      channel_1.add(current_user)
      sign_in(current_user)
    end

    xit "adds the emoji to the composer" do
      chat_page.visit_channel(channel_1)
      channel_page.open_action_menu
      channel_page.click_action_button("emoji")
      find("[data-emoji='grimacing']").click(wait: 0.5)

      expect(channel_page.composer.value).to eq(":grimacing:")
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
    before do
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "adds the emoji to the composer" do
      chat_page.visit_channel(channel_1)
      find(".chat-composer__input").fill_in(with: ":gri")
      find(".emoji-shortname", text: "grimacing").click

      expect(channel_page.composer.value).to eq(":grimacing: ")
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
    before do
      channel_1.add(current_user)
      sign_in(current_user)
    end

    xit "prefills the emoji picker filter input" do
      chat_page.visit_channel(channel_1)
      find(".chat-composer__input").fill_in(with: ":gri")

      click_link(I18n.t("js.composer.more_emoji"))

      expect(find(".chat-emoji-picker .dc-filter-input").value).to eq("gri")
    end

    xit "filters with the prefilled input" do
      chat_page.visit_channel(channel_1)
      find(".chat-composer__input").fill_in(with: ":fr")

      click_link(I18n.t("js.composer.more_emoji"))

      expect(page).to have_selector(".chat-emoji-picker [data-emoji='fr']")
      expect(page).to have_no_selector(".chat-emoji-picker [data-emoji='grinning']")
    end
  end

  context "when typing on keyboard" do
    before do
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "propagates keys to composer" do
      chat_page.visit_channel(channel_1)

      find("body").send_keys("b")

      expect(channel_page.composer.value).to eq("b")

      find("body").send_keys("b")

      expect(channel_page.composer.value).to eq("bb")

      find("body").send_keys(:enter) # special case

      expect(channel_page.composer.value).to eq("bb")
    end
  end

  context "when pasting link over selected text" do
    before do
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "outputs a markdown link" do
      modifier = /darwin/i =~ RbConfig::CONFIG["host_os"] ? :command : :control
      select_text = <<-JS
        const element = document.querySelector(arguments[0]);
        element.focus();
        element.setSelectionRange(0, element.value.length)
      JS

      chat_page.visit_channel(channel_1)

      find("body").send_keys("https://www.discourse.org")
      page.execute_script(select_text, ".chat-composer__input")

      page.send_keys [modifier, "c"]
      page.send_keys [:backspace]

      find("body").send_keys("discourse")
      page.execute_script(select_text, ".chat-composer__input")

      page.send_keys [modifier, "v"]

      expect(channel_page.composer.value).to eq("[discourse](https://www.discourse.org)")
    end
  end

  context "when posting a message with length equal to minimum length" do
    before do
      SiteSetting.chat_minimum_message_length = 1
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "works" do
      chat_page.visit_channel(channel_1)
      find("body").send_keys("1")
      channel_page.click_send_message

      expect(channel_page).to have_message(text: "1")
    end
  end

  context "when posting a message with length superior to minimum length" do
    before do
      SiteSetting.chat_minimum_message_length = 2
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "doesn’t allow to send" do
      chat_page.visit_channel(channel_1)
      find("body").send_keys("1")

      expect(page).to have_css(".chat-composer.is-send-disabled")
    end
  end

  context "when upload is in progress" do
    before do
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "doesn’t allow to send" do
      chat_page.visit_channel(channel_1)

      page.driver.browser.network_conditions = { latency: 20_000 }

      file_path = file_from_fixtures("logo.png", "images").path
      attach_file(file_path) do
        channel_page.open_action_menu
        channel_page.click_action_button("chat-upload-btn")
      end

      expect(page).to have_css(".chat-composer-upload--in-progress")
      expect(page).to have_css(".chat-composer.is-send-disabled")

      page.driver.browser.network_conditions = { latency: 0 }
    end
  end
end
