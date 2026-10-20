# frozen_string_literal: true

RSpec.describe "Chat composer formatting" do
  fab!(:current_user, :user)
  fab!(:channel_1, :chat_channel)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    SiteSetting.enable_composer_picker_and_rich_chat = true
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  after { page.execute_script(<<~JS) }
      Object.keys(localStorage)
        .filter((key) => key.startsWith("discourse_chat_composer_"))
        .forEach((key) => localStorage.removeItem(key));
    JS

  context "with the rich editor" do
    before do
      current_user.user_option.update!(composition_mode: UserOption.composition_mode_types[:rich])
    end

    it "formats a selection from the floating toolbar" do
      chat_page.visit_channel(channel_1)
      channel_page.composer.input.send_keys("ship it now")
      channel_page.composer.input.send_keys(*Array.new(3) { %i[shift left] })

      find(".fk-d-menu[data-identifier='composer-selection-toolbar'] .bold").click

      expect(channel_page.composer).to have_value("ship it **now**")
    end

    it "leaves selections to the formatting bar while it is shown" do
      chat_page.visit_channel(channel_1)
      channel_page.composer.toggle_formatting_bar
      channel_page.composer.input.send_keys("ship it now")
      channel_page.composer.input.send_keys(*Array.new(3) { %i[shift left] })

      expect(page).to have_css(".chat-composer__formatting-bar")
      expect(page).to have_no_css(".fk-d-menu[data-identifier='composer-selection-toolbar']")
    end

    it "hides the floating toolbar without a selection" do
      chat_page.visit_channel(channel_1)
      channel_page.composer.input.send_keys("ship it now")

      expect(page).to have_no_css(".fk-d-menu[data-identifier='composer-selection-toolbar']")
    end
  end

  %i[markdown rich].each do |composition_mode|
    context "with the #{composition_mode} editor" do
      before do
        current_user.user_option.update!(
          composition_mode: UserOption.composition_mode_types[composition_mode],
        )
      end

      it "toggles a formatting bar that applies formatting" do
        chat_page.visit_channel(channel_1)
        expect(page).to have_no_css(".chat-composer__formatting-bar")

        channel_page.composer.toggle_formatting_bar
        channel_page.composer.input.send_keys(
          "groceries",
          [SystemHelpers::PLATFORM_KEY_MODIFIER, "a"],
        )
        find(".chat-composer__formatting-bar .bullet-list").click

        expect(channel_page.composer).to have_value("* groceries")

        channel_page.composer.toggle_formatting_bar

        expect(page).to have_no_css(".chat-composer__formatting-bar")
      end

      it "strikes text and wraps lines in a code block" do
        chat_page.visit_channel(channel_1)
        channel_page.composer.toggle_formatting_bar

        channel_page.composer.input.send_keys("gone", [SystemHelpers::PLATFORM_KEY_MODIFIER, "a"])
        find(".chat-composer__formatting-bar .strikethrough").click

        expect(channel_page.composer).to have_value("~~gone~~")

        channel_page.composer.input.send_keys(
          [SystemHelpers::PLATFORM_KEY_MODIFIER, "a"],
          :backspace,
          "x = 1",
          %i[shift enter],
          "y = 2",
          [SystemHelpers::PLATFORM_KEY_MODIFIER, "a"],
        )
        find(".chat-composer__formatting-bar .code").click

        expect(channel_page.composer).to have_value("```\nx = 1\ny = 2\n```")
      end
    end
  end
end
