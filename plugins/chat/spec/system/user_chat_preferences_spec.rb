# frozen_string_literal: true

RSpec.describe "User chat preferences", type: :system do
  fab!(:current_user, :user)

  let(:user_preferences_chat_page) { PageObjects::Pages::UserPreferencesChat.new }
  let(:emoji_picker) { PageObjects::Components::EmojiPicker.new }
  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }

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
    form.field("chat_quick_reaction_type").select("custom")

    custom_field = form.field("chat_quick_reactions_custom")
    expect(custom_field.component).to have_css(".emoji-picker-trigger", count: 3, wait: 5)

    reaction_buttons = custom_field.component.all("button.emoji-picker-trigger")
    expect(reaction_buttons.first.find("img")[:title]).to eq "heart"

    reaction_buttons.first.click
    emoji_picker.select_emoji(":sweat_smile:")
    form.submit
    user_preferences_chat_page.visit

    expect(
      form.field("chat_quick_reaction_type").component.find("input[type='radio'][value='custom']"),
    ).to be_checked

    custom_field = form.field("chat_quick_reactions_custom")
    reaction_buttons = custom_field.component.all("button.emoji-picker-trigger")
    expect(reaction_buttons.first.find("img")[:title]).to eq "sweat_smile"
  end

  describe "chat interface" do
    fab!(:category_channel_1, :category_channel)
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: category_channel_1) }

    xit "sees expected quick-reactions on hover" do
      sign_in(current_user)

      # save custom and look for reaction
      user_preferences_chat_page.visit
      form.field("chat_quick_reaction_type").select("custom")
      form.submit
      user_preferences_chat_page.visit
      chat.visit_channel(category_channel_1)
      channel.hover_message(message_1)

      expect(channel.find_quick_reaction("smile")).to be_present

      # save frequent and look for reaction
      user_preferences_chat_page.visit
      form.field("chat_quick_reaction_type").select("frequent")
      form.submit
      user_preferences_chat_page.visit
      chat.visit_channel(category_channel_1)
      channel.hover_message(message_1)

      expect(channel.find_quick_reaction("tada")).to be_present
    end
  end

  shared_examples "select and save" do
    it "can select and save" do
      user_preferences_chat_page.visit
      form.field(field_name).select(val)
      form.submit
      user_preferences_chat_page.visit

      expect(form.field(field_name).value).to eq val
    end
  end

  describe "chat sound" do
    include_examples "select and save" do
      let(:field_name) { "chat_sound" }
      let(:val) { "bell" }
    end
  end

  describe "header_indicator_preference" do
    include_examples "select and save" do
      let(:field_name) { "chat_header_indicator_preference" }
      let(:val) { "dm_and_mentions" }
    end
  end

  describe "separate sidebar mode" do
    include_examples "select and save" do
      let(:field_name) { "chat_separate_sidebar_mode" }
      let(:val) { "fullscreen" }
    end
  end

  it "can select send shorcut sidebar mode" do
    user_preferences_chat_page.visit
    form.field("chat_send_shortcut").select("meta_enter")
    form.submit
    user_preferences_chat_page.visit

    expect(
      form.field("chat_send_shortcut").component.find("input[type='radio'][value='meta_enter']"),
    ).to be_checked
  end

  context "as an admin on another user's preferences" do
    fab!(:current_user, :admin)
    fab!(:user_1, :user)

    before { sign_in(current_user) }

    it "allows to change settings" do
      visit("/u/#{user_1.username}/preferences")
      find(".user-nav__preferences-chat", visible: :all).click

      expect(page).to have_current_path("/u/#{user_1.username}/preferences/chat")
    end
  end
end
