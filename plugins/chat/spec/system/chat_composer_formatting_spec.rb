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

  shared_examples "a formatting bar" do |composition_mode|
    before do
      current_user.user_option.update!(
        composition_mode: UserOption.composition_mode_types[composition_mode],
      )
    end

    it "keeps the menu open while toggling the formatting bar" do
      chat_page.visit_channel(channel_1)
      channel_page.composer.open_dropdown
      toggle = ".chat-composer-dropdown__toggle.toggle-formatting"
      checkbox = "#{toggle} .d-toggle-switch__checkbox"

      find("#{toggle} .d-toggle-switch__checkbox-slider").click

      expect(page).to have_css(".chat-composer__formatting-bar")
      expect(page).to have_css("#{checkbox}[aria-checked='true']", visible: :all)

      find("#{toggle} .chat-composer-dropdown__toggle-label").click

      expect(page).to have_no_css(".chat-composer__formatting-bar")
      expect(page).to have_css("#{checkbox}[aria-checked='false']", visible: :all)
    end

    it "advertises chat's own link shortcut" do
      chat_page.visit_channel(channel_1)
      channel_page.composer.toggle_formatting_bar

      expect(find(".chat-composer__formatting-bar .link")["aria-keyshortcuts"]).to end_with("+L")
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

      # the textarea leaves the caret on a new line after the fence
      trailing = composition_mode == :markdown ? "\n" : ""
      expect(channel_page.composer).to have_value("```\nx = 1\ny = 2\n```#{trailing}")
    end
  end

  context "with the rich editor" do
    include_examples "a formatting bar", :rich

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

    it "keeps the selection while navigating and activating the floating toolbar by keyboard" do
      chat_page.visit_channel(channel_1)
      channel_page.composer.input.send_keys("ship it now")
      channel_page.composer.input.send_keys(*Array.new(3) { %i[shift left] })

      toolbar = ".fk-d-menu[data-identifier='composer-selection-toolbar']"
      expect(page).to have_css("#{toolbar} .bold")
      channel_page.composer.input.send_keys(:tab)
      expect(page).to have_css("#{toolbar} .bold:focus")
      find("#{toolbar} .bold:focus").send_keys(:right)
      expect(page).to have_css("#{toolbar} .italic:focus")
      find("#{toolbar} .italic:focus").send_keys(:enter)
      expect(channel_page.composer).to have_value("ship it *now*")

      channel_page.composer.input.send_keys(:tab)
      expect(page).to have_css("#{toolbar} .bold:focus")
      find("#{toolbar} .bold:focus").send_keys(:escape)
      expect(page).to have_css(".chat-composer__input:focus")
      expect(page).to have_no_css(toolbar)
      channel_page.composer.input.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, "b"])
      expect(channel_page.composer).to have_value("ship it ***now***")
    end

    it "leaves a selected image to its own toolbar" do
      chat_page.visit_channel(channel_1)
      expect(channel_page.composer).to have_rich_editor
      page.execute_script(<<~JS)
        const editor = Discourse.lookup("service:chat-channel-composer").editor;
        const view = editor.textManipulation?.view ?? editor.view;
        const { schema } = view.state;
        const image = schema.nodes.image.create({ src: "/images/avatar.png", alt: "avatar" });
        const paragraph = schema.nodes.paragraph.create(null, [schema.text("a "), image]);
        view.dispatch(view.state.tr.replaceWith(0, view.state.doc.content.size, paragraph));
      JS

      find(".chat-composer__input img[alt='avatar']", match: :first).click

      # a bounded wait, since absence alone passes before the menu would open
      shown = page.evaluate_async_script(<<~JS)
        const done = arguments[0];
        const started = Date.now();
        const poll = () => {
          if (document.querySelector(".fk-d-menu[data-identifier='composer-selection-toolbar']")) {
            return done(true);
          }
          if (Date.now() - started > 1500) return done(false);
          setTimeout(poll, 50);
        };
        poll();
      JS
      expect(shown).to eq(false)
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

  context "with the markdown editor" do
    include_examples "a formatting bar", :markdown
  end
end
