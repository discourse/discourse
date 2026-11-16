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

  after { page.execute_script("localStorage.removeItem('discourse_chat_composer_formatting_bar')") }

  context "with the rich editor" do
    before do
      current_user.user_option.update!(composition_mode: UserOption.composition_mode_types[:rich])
    end

    it "formats a selection from the floating toolbar" do
      chat_page.visit_channel(channel_1)
      channel_page.composer.input.send_keys("ship it now")
      channel_page.composer.input.send_keys(*Array.new(3) { %i[shift left] })

      find(".fk-d-menu[data-identifier='chat-selection-toolbar'] .bold").click

      expect(channel_page.composer).to have_value("ship it **now**")
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
          if (document.querySelector(".fk-d-menu[data-identifier='chat-selection-toolbar']")) {
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
      find(".chat-composer-button.-toggle-formatting").click
      channel_page.composer.input.send_keys("ship it now")
      channel_page.composer.input.send_keys(*Array.new(3) { %i[shift left] })

      expect(page).to have_css(".chat-composer__formatting-bar")
      expect(page).to have_no_css(".fk-d-menu[data-identifier='chat-selection-toolbar']")
    end

    it "hides the floating toolbar without a selection" do
      chat_page.visit_channel(channel_1)
      channel_page.composer.input.send_keys("ship it now")

      expect(page).to have_no_css(".fk-d-menu[data-identifier='chat-selection-toolbar']")
    end
  end

  %i[markdown rich].each do |composition_mode|
    context "with the #{composition_mode} editor" do
      before do
        current_user.user_option.update!(
          composition_mode: UserOption.composition_mode_types[composition_mode],
        )
      end

      it "advertises chat's own link shortcut" do
        chat_page.visit_channel(channel_1)
        find(".chat-composer-button.-toggle-formatting").click

        expect(find(".chat-composer__formatting-bar .link")["aria-keyshortcuts"]).to end_with("+L")
      end

      it "toggles a formatting bar that applies formatting" do
        chat_page.visit_channel(channel_1)
        expect(page).to have_no_css(".chat-composer__formatting-bar")

        find(".chat-composer-button.-toggle-formatting").click
        channel_page.composer.input.send_keys(
          "groceries",
          [SystemHelpers::PLATFORM_KEY_MODIFIER, "a"],
        )
        find(".chat-composer__formatting-bar .bullet-list").click

        expect(channel_page.composer).to have_value("* groceries")

        find(".chat-composer-button.-toggle-formatting").click

        expect(page).to have_no_css(".chat-composer__formatting-bar")
      end
    end
  end
end
