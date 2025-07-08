# frozen_string_literal: true

RSpec.describe "User chat preferences", type: :system do
  fab!(:current_user) { Fabricate(:user) }

  let(:user_preferences_chat_page) { PageObjects::Pages::UserPreferencesChat.new }
  let(:emoji_picker) { PageObjects::Components::EmojiPicker.new }
  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when chat disabled" do
    before do
      SiteSetting.chat_enabled = false
      sign_in(current_user)
    end

    it "doesn’t show the tab" do
      visit("/my/preferences")

      expect(page).to have_no_css(".user-nav__preferences-chat", visible: :all)
    end

    it "shows a not found page" do
      user_preferences_chat_page.visit

      expect(page).to have_content(I18n.t("page_not_found.title"))
    end
  end

  it "can change chat quick reaction type to custom and select emoji" do
    user_preferences_chat_page.visit
    choose("user_chat_quick_reaction_type", option: "custom")

    expect(user_preferences_chat_page.emoji_picker_triggers.count).to eq 3
    expect(user_preferences_chat_page.reactions_selected.first).to eq "heart"

    user_preferences_chat_page.reaction_buttons.first.click
    emoji_picker.select_emoji(":sweat_smile:")
    user_preferences_chat_page.save_changes_and_refresh

    expect(page).to have_checked_field("user_chat_quick_reaction_type_custom")
    expect(user_preferences_chat_page.reactions_selected.first).to eq "sweat_smile"
  end

  describe "chat interface" do
    fab!(:category_channel_1) { Fabricate(:category_channel) }
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: category_channel_1) }

    xit "sees expected quick-reactions on hover" do
      sign_in(current_user)

      # save custom and look for reaction
      user_preferences_chat_page.visit
      choose("user_chat_quick_reaction_type", option: "custom")
      user_preferences_chat_page.save_changes_and_refresh
      chat.visit_channel(category_channel_1)
      channel.hover_message(message_1)

      expect(channel.find_quick_reaction("smile")).to be_present

      # save frequent and look for reaction
      user_preferences_chat_page.visit
      find("#user_chat_quick_reaction_type_frequent").click
      user_preferences_chat_page.save_changes_and_refresh
      chat.visit_channel(category_channel_1)
      channel.hover_message(message_1)

      expect(channel.find_quick_reaction("tada")).to be_present
    end
  end

  shared_examples "select and save" do
    it "can select and save" do
      user_preferences_chat_page.visit
      user_preferences_chat_page.select_option_value(sel, val)
      user_preferences_chat_page.save_changes_and_refresh

      expect(user_preferences_chat_page.selected_option_value(sel)).to eq val
    end
  end

  describe "chat sound" do
    include_examples "select and save" do
      let(:sel) { "#user_chat_sounds" }
      let(:val) { "bell" }
    end
  end

  describe "header_indicator_preference" do
    include_examples "select and save" do
      let(:sel) { "#user_chat_header_indicator_preference" }
      let(:val) { "dm_and_mentions" }
    end
  end

  describe "separate sidebar mode" do
    include_examples "select and save" do
      let(:sel) { "#user_chat_separate_sidebar_mode" }
      let(:val) { "fullscreen" }
    end
  end

  it "can select send shorcut sidebar mode" do
    user_preferences_chat_page.visit
    find("#chat_send_shortcut_meta_enter").click
    user_preferences_chat_page.save_changes_and_refresh

    expect(page).to have_checked_field("chat_send_shortcut_meta_enter")
  end

  context "as an admin on another user's preferences" do
    fab!(:current_user) { Fabricate(:admin) }
    fab!(:user_1) { Fabricate(:user) }

    before { sign_in(current_user) }

    it "allows to change settings" do
      visit("/u/#{user_1.username}/preferences")
      find(".user-nav__preferences-chat", visible: :all).click

      expect(page).to have_current_path("/u/#{user_1.username}/preferences/chat")
    end
  end
end
