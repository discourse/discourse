# frozen_string_literal: true

describe "Post translations" do
  POST_LANGUAGE_SWITCHER_SELECTOR = ".d-editor-button-bar .post-language-selector-trigger"

  fab!(:admin)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:) }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:translation_selector) do
    PageObjects::Components::SelectKit.new(".translation-selector-dropdown")
  end
  let(:post_language_selector) do
    PageObjects::Components::DMenu.new(
      POST_LANGUAGE_SWITCHER_SELECTOR,
      "toolbar-menu__post-language-selector-trigger",
    )
  end
  let(:view_translations_modal) { PageObjects::Modals::ViewTranslationsModal.new }

  before do
    SiteSetting.default_locale = "en"
    SiteSetting.content_localization_supported_locales = "fr|es|pt_BR"
    SiteSetting.post_menu =
      "read|like|copyLink|flag|edit|bookmark|delete|admin|reply|addTranslation"
    SiteSetting.post_menu_hidden_items = "flag|bookmark|edit|addTranslation|delete|admin"
    SiteSetting.content_localization_enabled = true
    sign_in(admin)
  end

  context "when a post does not have translations" do
    it "shows only languages configured in the site setting" do
      post.update!(locale: "en")

      topic_page.visit_topic(topic)

      topic_page.click_post_action_button(post, :show_more)
      topic_page.click_post_action_button(post, :add_translation)
      browser_root
        .locator(".update-translations-menu__add .post-action-menu__add-translation")
        .filter(visible: true)
        .click
      translation_selector.expand
      expect(
        browser_root
          .locator(".translation-selector-dropdown .select-kit-collection li")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .count,
      ).to eq(3)
      expect(translation_selector).to have_option_value("fr")
      expect(translation_selector).to have_option_value("es")
      expect(translation_selector).to have_option_value("pt_BR")
      expect(translation_selector).to have_no_option_value("de")
    end

    it "allows a user to translate a post" do
      topic_page.visit_topic(topic)
      topic_page.click_post_action_button(post, :show_more)
      topic_page.click_post_action_button(post, :add_translation)
      browser_root
        .locator(".update-translations-menu__add .post-action-menu__add-translation")
        .filter(visible: true)
        .click
      expect(composer).to be_opened
      translation_selector.expand
      translation_selector.select_row_by_value("fr")
      browser_root
        .locator("#translated-topic-title")
        .filter(visible: true)
        .fill("Ceci est un sujet de test 0")
      composer.fill_content("Bonjour le monde")
      composer.submit
      expect(composer).to be_closed

      expect(TopicLocalization.exists?(topic_id: topic.id, locale: "fr")).to be true
      expect(PostLocalization.exists?(post_id: post.id, locale: "fr")).to be true
      expect(PostLocalization.find_by(post_id: post.id, locale: "fr").raw).to eq("Bonjour le monde")
      expect(TopicLocalization.find_by(topic_id: topic.id, locale: "fr").title).to eq(
        "Ceci est un sujet de test 0",
      )
    end
  end

  context "when a post already has translations" do
    fab!(:post_localization) do
      Fabricate(:post_localization, post: post, locale: "fr", raw: "Bonjour le monde")
    end
    let(:confirmation_dialog) { PageObjects::Components::Dialog.new }

    it "allows a user to add a new translation" do
      topic_page.visit_topic(topic)
      topic_page.click_post_action_button(post, :show_more)
      topic_page.click_post_action_button(post, :add_translation)
      browser_root
        .locator(".update-translations-menu__add .post-action-menu__add-translation")
        .filter(visible: true)
        .click
      expect(composer).to be_opened
      translation_selector.expand
      translation_selector.select_row_by_value("es")
      browser_root
        .locator("#translated-topic-title")
        .filter(visible: true)
        .fill("Este es un tema de prueba 0")
      composer.fill_content("Hola mundo")
      composer.submit
      expect(composer).to be_closed

      expect(TopicLocalization.exists?(topic_id: topic.id, locale: "es")).to be true
      expect(PostLocalization.exists?(post_id: post.id, locale: "es")).to be true
      expect(PostLocalization.find_by(post_id: post.id, locale: "es").raw).to eq("Hola mundo")
      expect(TopicLocalization.find_by(topic_id: topic.id, locale: "es").title).to eq(
        "Este es un tema de prueba 0",
      )
    end

    it "allows a user to see locales translated" do
      topic_page.visit_topic(topic)
      topic_page.click_post_action_button(post, :show_more)
      topic_page.click_post_action_button(post, :add_translation)
      view_translation_button =
        browser_root.locator(".post-action-menu__view-translation").filter(visible: true)
      expect(view_translation_button).to PlaywrightMatchers.be_visible
      expect(view_translation_button).to PlaywrightMatchers.contain_text(
        browser_text_pattern(I18n.t("js.post.localizations.view", { count: 1 })),
        useInnerText: true,
      )

      view_translation_button.click
      expect(view_translations_modal).to be_open
      expect(
        browser_root.locator(".post-translations-modal__locale").filter(visible: true),
      ).to PlaywrightMatchers.contain_text(browser_text_pattern("fr"), useInnerText: true)
    end

    it "lets a user set independent post and topic title languages without closing the modal" do
      post.update!(locale: nil)
      topic.update!(locale: nil)
      toasts = PageObjects::Components::Toasts.new

      topic_page.visit_topic(topic)
      topic_page.open_post_translations(post)

      expect(view_translations_modal).to be_open
      expect(view_translations_modal).to have_language_notice
      expect(view_translations_modal).to have_translation_language("French (Français) (fr)")

      view_translations_modal.select_post_language("English (en)").save_post_language

      expect(toasts).to have_success(I18n.t("js.post.localizations.modal.post_language_updated"))
      expect(view_translations_modal).to be_open
      expect(view_translations_modal).to have_language_notice

      view_translations_modal.select_topic_language("Spanish (Español) (es)").save_topic_language

      expect(toasts).to have_success(I18n.t("js.post.localizations.modal.topic_language_updated"))
      expect(view_translations_modal).to be_open
      view_translations_modal.close

      browser_page.reload.tap { SystemBrowserBootstrap.wait_for(browser_page) }
      topic_page.open_post_translations(post)

      expect(view_translations_modal).to have_post_language("English (en)")
      expect(view_translations_modal).to have_topic_language("Spanish (Español) (es)")
    end

    it "allows a user to edit a translation" do
      topic_page.visit_topic(topic)
      topic_page.click_post_action_button(post, :show_more)
      topic_page.click_post_action_button(post, :add_translation)
      browser_root.locator(".post-action-menu__view-translation").filter(visible: true).click
      browser_root.locator(".post-translations-modal__edit-action .btn").filter(visible: true).click
      expect(composer).to be_opened
      expect(translation_selector).to have_selected_value("fr")
      browser_root
        .locator("#translated-topic-title")
        .filter(visible: true)
        .fill("C'est un sujet de test 0.")
      composer.fill_content("Bonjour le monde")
      composer.submit
      expect(composer).to be_closed

      expect(TopicLocalization.exists?(topic_id: topic.id, locale: "fr")).to be true
      expect(PostLocalization.exists?(post_id: post.id, locale: "fr")).to be true
      expect(PostLocalization.find_by(post_id: post.id, locale: "fr").raw).to eq("Bonjour le monde")
      expect(TopicLocalization.find_by(topic_id: topic.id, locale: "fr").title).to eq(
        "C'est un sujet de test 0.",
      )
    end

    it "allows a user in content_localization_allowed_groups to delete a translation" do
      topic_page.visit_topic(topic)
      expect(PostLocalization.exists?(post_id: post.id, locale: "fr")).to be true

      topic_page.click_post_action_button(post, :show_more)
      topic_page.click_post_action_button(post, :add_translation)
      browser_root
        .locator(".update-translations-menu__add .post-action-menu__add-translation")
        .filter(visible: true)
        .click
      browser_root.locator(".post-action-menu__view-translation").filter(visible: true).click
      browser_root
        .locator(".post-translations-modal__delete-action .btn")
        .filter(visible: true)
        .click
      expect(confirmation_dialog).to be_open
      confirmation_dialog.click_yes

      expect(PostLocalization.exists?(post_id: post.id, locale: "fr")).to be false
    end

    it "prompts to discard changes when abandoning modified translation" do
      discard_modal = PageObjects::Modals::DiscardDraft.new

      topic_page.visit_topic(topic)
      topic_page.click_post_action_button(post, :show_more)
      topic_page.click_post_action_button(post, :add_translation)
      browser_root
        .locator(".update-translations-menu__add .post-action-menu__add-translation")
        .filter(visible: true)
        .click
      expect(composer).to be_opened

      translation_selector.expand
      translation_selector.select_row_by_value("fr")

      composer.fill_content("Salut le monde")
      composer.minimize
      expect(composer).to be_minimized

      browser_root
        .locator("#post_#{post.post_number} .post-action-menu__reply")
        .filter(visible: true)
        .click

      expect(discard_modal).to be_open
    end

    it "auto-closes when abandoning unchanged translation" do
      discard_modal = PageObjects::Modals::DiscardDraft.new

      topic_page.visit_topic(topic)
      topic_page.click_post_action_button(post, :show_more)
      topic_page.click_post_action_button(post, :add_translation)
      browser_root
        .locator(".update-translations-menu__add .post-action-menu__add-translation")
        .filter(visible: true)
        .click
      expect(composer).to be_opened

      translation_selector.expand
      translation_selector.select_row_by_value("fr")

      composer.minimize
      expect(composer).to be_minimized

      browser_root
        .locator("#post_#{post.post_number} .post-action-menu__reply")
        .filter(visible: true)
        .click

      expect(discard_modal).to be_closed
      expect(composer).to be_opened
    end
  end

  context "when creating a new post in a different locale" do
    it "shows configured languages, the default locale, and no locale" do
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      browser_root.locator("#create-topic").filter(visible: true).click
      post_language_selector.expand
      expect(post_language_selector).to have_displayed_content("English") # default locale
      expect(post_language_selector).to have_displayed_content("French (Français)")
      expect(post_language_selector).to have_displayed_content("Spanish (Español)")
      expect(post_language_selector).to have_displayed_content("Portuguese (Português (BR))")
      expect(post_language_selector).to have_displayed_content(
        I18n.t("js.post.localizations.post_language_selector.none"),
      )
    end

    it "allows a user to create a post in another locale" do
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      browser_root.locator("#create-topic").filter(visible: true).click
      post_language_selector.expand
      post_language_selector.option("[data-name='fr']").click
      composer.fill_title("Ceci est un sujet de test 1")
      composer.fill_content("Bonjour le monde")
      composer.submit
      expect(composer).to be_closed

      updated_post = Topic.last.posts.first
      expect(updated_post.locale).to eq("fr")
    end

    it "does not select a locale by default" do
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      browser_root.locator("#create-topic").filter(visible: true).click
      expect(
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            "#{POST_LANGUAGE_SWITCHER_SELECTOR} .toolbar-popup-menu-options__trigger-label",
          ).filter(visible: true),
        ),
      ).to be true
    end
  end

  context "when viewing raw markdown in translation editor" do
    fab!(:markdown_post) do
      Fabricate(
        :post,
        topic: topic,
        raw: "# Heading\n\n**Bold** text with [link](https://example.com) and *italic*",
      )
    end
    let(:translation_preview) { PageObjects::Components::DEditorOriginalTranslationPreview.new }

    it "shows raw markdown toggle only on Original tab" do
      topic_page.visit_topic(topic)
      topic_page.click_post_action_button(post, :show_more)
      topic_page.click_post_action_button(post, :add_translation)
      browser_root
        .locator(".update-translations-menu__add .post-action-menu__add-translation")
        .filter(visible: true)
        .click

      expect(composer).to be_opened
      expect(translation_preview).to have_raw_toggle
      expect(translation_preview.original_tab_active?).to be true

      translation_preview.click_translation_tab
      expect(translation_preview.translation_tab_active?).to be true
      expect(translation_preview).to have_no_raw_toggle
    end

    it "displays rendered HTML by default" do
      topic_page.visit_topic(topic)
      topic_page.click_post_action_button(post, :show_more)
      topic_page.click_post_action_button(post, :add_translation)
      browser_root
        .locator(".update-translations-menu__add .post-action-menu__add-translation")
        .filter(visible: true)
        .click

      expect(composer).to be_opened
      expect(translation_preview.original_tab_active?).to be true
      expect(translation_preview).to have_rendered_content
      expect(translation_preview).to have_no_raw_markdown_content
    end

    it "displays raw markdown when toggle is enabled" do
      topic_page.visit_topic(topic)
      topic_page.click_post_action_button(markdown_post.post_number, :show_more)
      topic_page.click_post_action_button(markdown_post.post_number, :add_translation)
      browser_root
        .locator(".update-translations-menu__add .post-action-menu__add-translation")
        .filter(visible: true)
        .click

      expect(composer).to be_opened
      translation_preview.raw_toggle.toggle

      expect(translation_preview).to have_raw_markdown_content
      raw_content = translation_preview.raw_markdown_content
      expect(raw_content).to include("# Heading")
      expect(raw_content).to include("**Bold**")
      expect(raw_content).to include("[link](https://example.com)")
      expect(raw_content).to include("*italic*")
    end

    it "resets raw markdown view when switching tabs" do
      topic_page.visit_topic(topic)
      topic_page.click_post_action_button(post, :show_more)
      topic_page.click_post_action_button(post, :add_translation)
      browser_root
        .locator(".update-translations-menu__add .post-action-menu__add-translation")
        .filter(visible: true)
        .click

      expect(composer).to be_opened
      translation_preview.raw_toggle.toggle
      expect(translation_preview).to have_raw_markdown_content

      translation_preview.click_translation_tab
      expect(translation_preview).to have_no_raw_toggle

      translation_preview.click_original_tab
      expect(translation_preview).to have_raw_toggle
      expect(translation_preview.raw_toggle).to be_unchecked
      expect(translation_preview).to have_rendered_content
    end

    it "maintains raw markdown state while on Original tab" do
      topic_page.visit_topic(topic)
      topic_page.click_post_action_button(post, :show_more)
      topic_page.click_post_action_button(post, :add_translation)
      browser_root
        .locator(".update-translations-menu__add .post-action-menu__add-translation")
        .filter(visible: true)
        .click

      expect(composer).to be_opened
      translation_preview.raw_toggle.toggle
      expect(translation_preview).to have_raw_markdown_content

      translation_preview.raw_toggle.toggle
      expect(translation_preview).to have_no_raw_markdown_content
      expect(translation_preview).to have_rendered_content
    end
  end
end
