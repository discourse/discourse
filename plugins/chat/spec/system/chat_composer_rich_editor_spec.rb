# frozen_string_literal: true

RSpec.describe "Chat composer rich editor" do
  fab!(:current_user, :user)
  fab!(:other_user, :user)
  fab!(:channel_1, :chat_channel)
  fab!(:message_1) { Fabricate(:chat_message, user: current_user, chat_channel: channel_1) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    SiteSetting.enable_composer_picker_and_rich_chat = true
    chat_system_bootstrap
    channel_1.add(current_user)
    channel_1.add(other_user)
    current_user.user_option.update!(composition_mode: UserOption.composition_mode_types[:rich])
    sign_in(current_user)
  end

  it "keeps the markdown editor while the upcoming change is off" do
    SiteSetting.enable_composer_picker_and_rich_chat = false
    chat_page.visit_channel(channel_1)

    expect(channel_page.composer).to have_markdown_editor
    channel_page.open_action_menu
    expect(page).to have_no_css(".chat-composer-dropdown__action-btn.toggle-editor")
  end

  it "uses the editor the user prefers" do
    chat_page.visit_channel(channel_1)

    expect(channel_page.composer).to have_rich_editor

    current_user.user_option.update!(composition_mode: UserOption.composition_mode_types[:markdown])
    chat_page.visit_channel(channel_1)

    expect(channel_page.composer).to have_markdown_editor
  end

  it "switches editors from the composer menu, keeping the draft and saving the preference" do
    chat_page.visit_channel(channel_1)
    channel_page.composer.fill_in(with: "draft text")

    channel_page.composer.toggle_editor

    expect(channel_page.composer).to have_markdown_editor
    expect(channel_page.composer).to have_value("draft text")
    try_until_success do
      expect(current_user.user_option.reload.composition_mode).to eq(
        UserOption.composition_mode_types[:markdown],
      )
    end

    channel_page.composer.toggle_editor

    expect(channel_page.composer).to have_rich_editor
    expect(channel_page.composer).to have_value("draft text")
    try_until_success do
      expect(current_user.user_option.reload.composition_mode).to eq(
        UserOption.composition_mode_types[:rich],
      )
    end
  end

  it "switches editors with the keyboard shortcut" do
    chat_page.visit_channel(channel_1)
    channel_page.composer.input.send_keys([:control, "m"])

    expect(channel_page.composer).to have_markdown_editor

    channel_page.composer.input.send_keys([:control, "m"])

    expect(channel_page.composer).to have_rich_editor
  end

  it "keeps Enter structural inside a list and sends from a plain paragraph" do
    chat_page.visit_channel(channel_1)
    channel_page.composer.input.send_keys("- first")
    channel_page.composer.enter_shortcut
    channel_page.composer.input.send_keys("second")

    expect(channel_page.composer).to have_value("* first\n* second")
    expect(channel_page.composer.input).to have_no_xpath("./p")

    channel_page.composer.enter_shortcut
    channel_page.composer.enter_shortcut

    expect(channel_page.composer).to have_value("* first\n* second")

    channel_page.composer.enter_shortcut

    expect(channel_page.messages).to have_message(text: "first")
    expect(page).to have_css(".chat-message-text ul li", count: 2)
  end

  it "inserts keys typed before focusing the composer as plain text" do
    chat_page.visit_channel(channel_1)
    find("body").send_keys(:escape)
    find("body").send_keys("-")
    find("body").send_keys("#")

    expect(channel_page.composer).to have_value("\\-#")
  end

  it "sends on Enter while text is selected" do
    chat_page.visit_channel(channel_1)
    channel_page.composer.input.send_keys("selected text")
    channel_page.composer.input.send_keys(%i[shift left], %i[shift left])
    channel_page.composer.enter_shortcut

    expect(channel_page.messages).to have_message(text: "selected text")
  end

  it "sends rich text as markdown" do
    chat_page.visit_channel(channel_1)
    channel_page.composer.fill_in(with: "**bold** text")
    channel_page.composer.enter_shortcut

    expect(channel_page.messages).to have_message(text: "bold text")
    expect(page).to have_css(".chat-message-text strong", text: "bold")
  end

  it "adds a line break on Enter when sending needs Mod+Enter" do
    current_user.user_option.update!(send_shortcut: "meta_enter")
    chat_page.visit_channel(channel_1)
    channel_page.composer.input.send_keys("line one")
    channel_page.composer.enter_shortcut
    channel_page.composer.input.send_keys("line two")

    expect(channel_page.composer).to have_value("line one\nline two")

    channel_page.composer.meta_enter_shortcut

    expect(channel_page.messages).to have_message(text: "line two")
  end

  it "edits the last message with ArrowUp and cancels with Escape" do
    chat_page.visit_channel(channel_1)
    channel_page.composer.edit_last_message_shortcut

    expect(channel_page.composer).to be_editing_message(message_1)

    channel_page.composer.cancel_shortcut

    expect(channel_page.composer).to be_editing_no_message
  end

  it "applies formatting shortcuts as marks" do
    chat_page.visit_channel(channel_1)
    channel_page.composer.bold_text_shortcut

    expect(channel_page.composer).to have_value("**strong text**")
  end

  it "completes emojis and mentions" do
    chat_page.visit_channel(channel_1)
    channel_page.composer.input.send_keys(":grimac")
    find(".emoji-shortname", text: "grimacing").click
    channel_page.composer.input.send_keys("@#{other_user.username}")
    find(".autocomplete.ac-user", text: other_user.username).click

    expect(channel_page.composer).to have_value(":grimacing: @#{other_user.username} ")
  end

  it "replaces a partial emoji term picked from the full picker" do
    chat_page.visit_channel(channel_1)
    channel_page.composer.input.send_keys("hey :gri")
    click_link(I18n.t("js.composer.more_emoji"))
    find(".emoji-picker [data-emoji='grimacing']").click

    expect(channel_page.composer).to have_value("hey :grimacing: ")
  end
end
