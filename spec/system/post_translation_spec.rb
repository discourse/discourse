# frozen_string_literal: true

describe "Post translations", type: :system do
  POST_LANGUAGE_SWITCHER_SELECTOR = "button[data-identifier='post-language-selector']"

  fab!(:admin)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:) }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:translation_selector) do
    PageObjects::Components::SelectKit.new(".translation-selector-dropdown")
  end
  let(:post_language_selector) do
    PageObjects::Components::DMenu.new(POST_LANGUAGE_SWITCHER_SELECTOR)
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
    it "should only show the languages listed in the site setting" do
      post.update!(locale: "en")

      topic_page.visit_topic(topic)

      topic_page.click_post_action_button(post, :show_more)
      topic_page.click_post_action_button(post, :add_translation)
      find(".update-translations-menu__add .post-action-menu__add-translation").click
      translation_selector.expand
      expect(all(".translation-selector-dropdown .select-kit-collection li").count).to eq(3)
      expect(translation_selector).to have_option_value("fr")
      expect(translation_selector).to have_option_value("es")
      expect(translation_selector).to have_option_value("pt_BR")
      expect(translation_selector).to have_no_option_value("de")
    end

    it "allows a user to translate a post" do
      topic_page.visit_topic(topic)
      topic_page.click_post_action_button(post, :show_more)
      topic_page.click_post_action_button(post, :add_translation)
      find(".update-translations-menu__add .post-action-menu__add-translation").click
      expect(composer).to be_opened
      translation_selector.expand
      translation_selector.select_row_by_value("fr")
      find("#translated-topic-title").fill_in(with: "Ceci est un sujet de test 0")
      composer.fill_content("Bonjour le monde")
      composer.submit

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
      find(".update-translations-menu__add .post-action-menu__add-translation").click
      expect(composer).to be_opened
      translation_selector.expand
      translation_selector.select_row_by_value("es")
      find("#translated-topic-title").fill_in(with: "Este es un tema de prueba 0")
      composer.fill_content("Hola mundo")
      composer.submit

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
      view_translation_button = find(".post-action-menu__view-translation")
      expect(view_translation_button).to be_visible
      expect(view_translation_button).to have_text(
        I18n.t("js.post.localizations.view", { count: 1 }),
      )

      view_translation_button.click
      expect(view_translations_modal).to be_open
      expect(find(".post-translations-modal__locale")).to have_text("fr")
    end

    it "allows a user to edit a translation" do
      topic_page.visit_topic(topic)
      topic_page.click_post_action_button(post, :show_more)
      topic_page.click_post_action_button(post, :add_translation)
      find(".post-action-menu__view-translation").click
      find(".post-translations-modal__edit-action .btn").click
      expect(composer).to be_opened
      expect(translation_selector).to have_selected_value("fr")
      find("#translated-topic-title").fill_in(with: "C'est un sujet de test 0.")
      composer.fill_content("Bonjour le monde")
      composer.submit

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
      find(".update-translations-menu__add .post-action-menu__add-translation").click
      find(".post-action-menu__view-translation").click
      find(".post-translations-modal__delete-action .btn").click
      expect(confirmation_dialog).to be_open
      confirmation_dialog.click_yes

      expect(PostLocalization.exists?(post_id: post.id, locale: "fr")).to be false
    end

    it "prompts to discard changes when abandoning modified translation" do
      discard_modal = PageObjects::Modals::DiscardDraft.new

      topic_page.visit_topic(topic)
      topic_page.click_post_action_button(post, :show_more)
      topic_page.click_post_action_button(post, :add_translation)
      find(".update-translations-menu__add .post-action-menu__add-translation").click
      expect(composer).to be_opened

      translation_selector.expand
      translation_selector.select_row_by_value("fr")

      composer.fill_content("Salut le monde")
      composer.minimize
      expect(composer).to be_minimized

      find("#post_#{post.post_number} .post-action-menu__reply").click

      expect(discard_modal).to be_open
    end

    it "auto-closes when abandoning unchanged translation" do
      discard_modal = PageObjects::Modals::DiscardDraft.new

      topic_page.visit_topic(topic)
      topic_page.click_post_action_button(post, :show_more)
      topic_page.click_post_action_button(post, :add_translation)
      find(".update-translations-menu__add .post-action-menu__add-translation").click
      expect(composer).to be_opened

      translation_selector.expand
      translation_selector.select_row_by_value("fr")

      composer.minimize
      expect(composer).to be_minimized

      find("#post_#{post.post_number} .post-action-menu__reply").click

      expect(discard_modal).to be_closed
      expect(composer).to be_opened
    end
  end

  context "when creating a new post in a different locale" do
    it "should only show the languages listed in the site setting and default locale and a none value" do
      visit("/latest")
      page.find("#create-topic").click
      post_language_selector.expand
      expect(post_language_selector).to have_content("English (US)") # default locale
      expect(post_language_selector).to have_content("French (Français)")
      expect(post_language_selector).to have_content("Spanish (Español)")
      expect(post_language_selector).to have_content("Portuguese (Português (BR))")
      expect(post_language_selector).to have_content(
        I18n.t("js.post.localizations.post_language_selector.none"),
      )
    end

    it "should allow a user to create a post in a different locale" do
      visit("/latest")
      page.find("#create-topic").click
      post_language_selector.expand
      post_language_selector.option(".dropdown-menu__item[data-menu-option-id='fr']").click
      composer.fill_title("Ceci est un sujet de test 1")
      composer.fill_content("Bonjour le monde")
      composer.submit

      updated_post = Topic.last.posts.first
      expect(updated_post.locale).to eq("fr")
    end

    it "should not have a locale set by default" do
      visit("/latest")
      page.find("#create-topic").click
      expect(page.has_no_css?("#{POST_LANGUAGE_SWITCHER_SELECTOR} .d-button-label")).to be true
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
      find(".update-translations-menu__add .post-action-menu__add-translation").click

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
      find(".update-translations-menu__add .post-action-menu__add-translation").click

      expect(composer).to be_opened
      expect(translation_preview.original_tab_active?).to be true
      expect(translation_preview).to have_rendered_content
      expect(translation_preview).to have_no_raw_markdown_content
    end

    it "displays raw markdown when toggle is enabled" do
      topic_page.visit_topic(topic)
      topic_page.click_post_action_button(markdown_post.post_number, :show_more)
      topic_page.click_post_action_button(markdown_post.post_number, :add_translation)
      find(".update-translations-menu__add .post-action-menu__add-translation").click

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
      find(".update-translations-menu__add .post-action-menu__add-translation").click

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
      find(".update-translations-menu__add .post-action-menu__add-translation").click

      expect(composer).to be_opened
      translation_preview.raw_toggle.toggle
      expect(translation_preview).to have_raw_markdown_content

      translation_preview.raw_toggle.toggle
      expect(translation_preview).to have_no_raw_markdown_content
      expect(translation_preview).to have_rendered_content
    end
  end
end
