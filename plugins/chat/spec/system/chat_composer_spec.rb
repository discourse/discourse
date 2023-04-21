# frozen_string_literal: true

RSpec.describe "Chat composer", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before { chat_system_bootstrap }

  xit "it stores draft in replies" do
  end

  xit "it stores draft" do
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
      expect(find(".chat-composer-input").value).to eq(message_2.message)
    end

    context "when pressing escape" do
      it "cancels editing" do
        chat.visit_channel(channel_1)
        channel.edit_message(message_2)
        find(".chat-composer-input").send_keys(:escape)

        expect(page).to have_no_selector(".chat-composer-message-details .chat-reply__username")
        expect(find(".chat-composer-input").value).to eq("")
      end
    end

    context "when closing edited message" do
      it "cancels editing" do
        chat.visit_channel(channel_1)
        channel.edit_message(message_2)
        find(".cancel-message-action").click

        expect(page).to have_no_selector(".chat-composer-message-details .chat-reply__username")
        expect(find(".chat-composer-input").value).to eq("")
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

      expect(find(".chat-composer-input").value).to eq(":grimacing:")
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
      find(".chat-composer-input").fill_in(with: ":gri")
      find(".emoji-shortname", text: "grimacing").click

      expect(find(".chat-composer-input").value).to eq(":grimacing: ")
    end

    it "doesn't suggest denied emojis and aliases" do
      SiteSetting.emoji_deny_list = "peach|poop"
      chat.visit_channel(channel_1)

      find(".chat-composer-input").fill_in(with: ":peac")
      expect(page).to have_no_selector(".emoji-shortname", text: "peach")

      find(".chat-composer-input").fill_in(with: ":hank") # alias
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
      find(".chat-composer-input").fill_in(with: ":gri")

      click_link(I18n.t("js.composer.more_emoji"))

      expect(find(".chat-emoji-picker .dc-filter-input").value).to eq("gri")
    end

    it "filters with the prefilled input" do
      chat.visit_channel(channel_1)
      find(".chat-composer-input").fill_in(with: ":fr")

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

      expect(find(".chat-composer-input").value).to eq("b")

      find("body").send_keys("b")

      expect(find(".chat-composer-input").value).to eq("bb")

      find("body").send_keys(:enter) # special case

      expect(find(".chat-composer-input").value).to eq("bb")
    end
  end
end
