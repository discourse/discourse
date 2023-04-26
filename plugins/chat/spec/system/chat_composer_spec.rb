# frozen_string_literal: true

RSpec.describe "Chat composer", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before { chat_system_bootstrap }

  context "when loading a channel with a draft" do
    fab!(:draft_1) do
      Chat::Draft.create!(
        chat_channel: channel_1,
        user: current_user,
        data: { message: "draft" }.to_json,
      )
    end

    before do
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "loads the draft" do
      chat.visit_channel(channel_1)

      expect(find(".chat-composer__input").value).to eq("draft")
    end

    context "with uploads" do
      fab!(:upload_1) do
        Fabricate(
          :upload,
          url: "/images/logo-dark.png",
          original_filename: "logo_dark.png",
          width: 400,
          height: 300,
          extension: "png",
        )
      end

      fab!(:draft_1) do
        Chat::Draft.create!(
          chat_channel: channel_1,
          user: current_user,
          data: { message: "draft", uploads: [upload_1] }.to_json,
        )
      end

      it "loads the draft with the upload" do
        chat.visit_channel(channel_1)

        expect(find(".chat-composer__input").value).to eq("draft")
        expect(page).to have_selector(".chat-composer-upload--image", count: 1)
      end
    end

    context "when replying" do
      fab!(:draft_1) do
        Chat::Draft.create!(
          chat_channel: channel_1,
          user: current_user,
          data: {
            message: "draft",
            replyToMsg: {
              id: message_1.id,
              excerpt: message_1.excerpt,
              user: {
                id: message_1.user.id,
                name: nil,
                avatar_template: message_1.user.avatar_template,
                username: message_1.user.username,
              },
            },
          }.to_json,
        )
      end

      it "loads the draft with replied to mesage" do
        chat.visit_channel(channel_1)

        expect(find(".chat-composer__input").value).to eq("draft")
        expect(page).to have_selector(".chat-reply__username", text: message_1.user.username)
        expect(page).to have_selector(".chat-reply__excerpt", text: message_1.excerpt)
      end
    end
  end

  context "when replying to a message" do
    before do
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "adds the reply indicator to the composer" do
      chat.visit_channel(channel_1)
      channel.reply_to(message_1)

      expect(page).to have_selector(
        ".chat-composer-message-details .chat-reply__username",
        text: message_1.user.username,
      )
    end

    context "with HTML tags" do
      before { message_1.update!(message: "<mark>not marked</mark>") }

      it "renders text in the details" do
        chat.visit_channel(channel_1)
        channel.reply_to(message_1)

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
      chat.visit_channel(channel_1)
      channel.edit_message(message_2)

      expect(page).to have_selector(
        ".chat-composer-message-details .chat-reply__username",
        text: current_user.username,
      )
      expect(find(".chat-composer__input").value).to eq(message_2.message)
    end

    context "when pressing escape" do
      it "cancels editing" do
        chat.visit_channel(channel_1)
        channel.edit_message(message_2)
        find(".chat-composer__input").send_keys(:escape)

        expect(page).to have_no_selector(".chat-composer-message-details .chat-reply__username")
        expect(find(".chat-composer__input").value).to eq("")
      end
    end

    context "when closing edited message" do
      it "cancels editing" do
        chat.visit_channel(channel_1)
        channel.edit_message(message_2)
        find(".cancel-message-action").click

        expect(page).to have_no_selector(".chat-composer-message-details .chat-reply__username")
        expect(find(".chat-composer__input").value).to eq("")
      end
    end
  end

  context "when adding an emoji through the picker" do
    before do
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "adds the emoji to the composer" do
      chat.visit_channel(channel_1)
      channel.open_action_menu
      channel.click_action_button("emoji")
      find("[data-emoji='grimacing']").click(wait: 0.5)

      expect(find(".chat-composer__input").value).to eq(":grimacing:")
    end

    it "removes denied emojis from insert emoji picker" do
      SiteSetting.emoji_deny_list = "monkey|peach"

      chat.visit_channel(channel_1)
      channel.open_action_menu
      channel.click_action_button("emoji")

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
      chat.visit_channel(channel_1)
      find(".chat-composer__input").fill_in(with: ":gri")
      find(".emoji-shortname", text: "grimacing").click

      expect(find(".chat-composer__input").value).to eq(":grimacing: ")
    end

    it "doesn't suggest denied emojis and aliases" do
      SiteSetting.emoji_deny_list = "peach|poop"
      chat.visit_channel(channel_1)

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
      chat.visit_channel(channel_1)
      find(".chat-composer__input").fill_in(with: ":gri")

      click_link(I18n.t("js.composer.more_emoji"))

      expect(find(".chat-emoji-picker .dc-filter-input").value).to eq("gri")
    end

    xit "filters with the prefilled input" do
      chat.visit_channel(channel_1)
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
      chat.visit_channel(channel_1)

      find("body").send_keys("b")

      expect(find(".chat-composer__input").value).to eq("b")

      find("body").send_keys("b")

      expect(find(".chat-composer__input").value).to eq("bb")

      find("body").send_keys(:enter) # special case

      expect(find(".chat-composer__input").value).to eq("bb")
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

      chat.visit_channel(channel_1)

      find("body").send_keys("https://www.discourse.org")
      page.execute_script(select_text, ".chat-composer__input")

      page.send_keys [modifier, "c"]
      page.send_keys [:backspace]

      find("body").send_keys("discourse")
      page.execute_script(select_text, ".chat-composer__input")

      page.send_keys [modifier, "v"]

      expect(find(".chat-composer__input").value).to eq("[discourse](https://www.discourse.org)")
    end
  end

  context "when posting a message with length equal to minimum length" do
    before do
      SiteSetting.chat_minimum_message_length = 1
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "works" do
      chat.visit_channel(channel_1)
      find("body").send_keys("1")
      channel.click_send_message

      expect(channel).to have_message(text: "1")
    end
  end

  context "when posting a message with length superior to minimum length" do
    before do
      SiteSetting.chat_minimum_message_length = 2
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "doesn’t allow to send" do
      chat.visit_channel(channel_1)
      find("body").send_keys("1")

      expect(page).to have_css(".chat-composer--send-disabled")
    end
  end
end
