# frozen_string_literal: true

RSpec.describe "Chat composer editor toggle" do
  fab!(:current_user, :user)
  fab!(:channel_1, :chat_channel)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    current_user.user_option.update!(composition_mode: UserOption.composition_mode_types[:rich])
    sign_in(current_user)
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

  it "sends rich text as markdown" do
    chat_page.visit_channel(channel_1)
    channel_page.composer.fill_in(with: "**bold** text")
    channel_page.composer.enter_shortcut

    expect(channel_page.messages).to have_message(text: "bold text")
    expect(page).to have_css(".chat-message-text strong", text: "bold")
  end
end
