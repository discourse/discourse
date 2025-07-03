# frozen_string_literal: true

describe "Post translations", type: :system do
  POST_LANGUAGE_SWITCHER_SELECTOR = "button[data-identifier='post-language-selector']"

  fab!(:admin)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, user: admin) }
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
    sign_in(admin)
    SiteSetting.default_locale = "en"
    SiteSetting.content_localization_supported_locales = "fr|es|pt_BR"
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.post_menu =
      "read|like|copyLink|flag|edit|bookmark|delete|admin|reply|addTranslation"
  end

  context "when a post does not have translations" do
    it "should only show the languages listed in the site setting" do
      topic_page.visit_topic(topic)
      find("#post_#{post.post_number} .post-action-menu__add-translation").click
      translation_selector.expand
      expect(all(".translation-selector-dropdown .select-kit-collection li").count).to eq(3)
      expect(translation_selector).to have_option_value("fr")
      expect(translation_selector).to have_option_value("es")
      expect(translation_selector).to have_option_value("pt_BR")
      expect(translation_selector).to have_no_option_value("de")
    end

    it "allows a user to translate a post" do
      topic_page.visit_topic(topic)
      find("#post_#{post.post_number} .post-action-menu__add-translation").click
      expect(composer).to be_opened
      translation_selector.expand
      translation_selector.select_row_by_value("fr")
      find("#translated-topic-title").fill_in(with: "Ceci est un sujet de test 0")
      composer.fill_content("Bonjour le monde")
      composer.submit
      post.reload
      topic.reload

      try_until_success do
        expect(TopicLocalization.exists?(topic_id: topic.id, locale: "fr")).to be true
        expect(PostLocalization.exists?(post_id: post.id, locale: "fr")).to be true
        expect(PostLocalization.find_by(post_id: post.id, locale: "fr").raw).to eq(
          "Bonjour le monde",
        )
        expect(TopicLocalization.find_by(topic_id: topic.id, locale: "fr").title).to eq(
          "Ceci est un sujet de test 0",
        )
      end
    end
  end

  context "when a post already has translations" do
    fab!(:post_localization) do
      Fabricate(:post_localization, post: post, locale: "fr", raw: "Bonjour le monde")
    end
    let(:confirmation_dialog) { PageObjects::Components::Dialog.new }

    it "allows a user to add a new translation" do
      topic_page.visit_topic(topic)
      find("#post_1 .post-action-menu-edit-translations-trigger").click
      find(".update-translations-menu__add .post-action-menu__add-translation").click
      expect(composer).to be_opened
      translation_selector.expand
      translation_selector.select_row_by_value("es")
      find("#translated-topic-title").fill_in(with: "Este es un tema de prueba 0")
      composer.fill_content("Hola mundo")
      composer.submit
      post.reload
      topic.reload

      try_until_success do
        expect(TopicLocalization.exists?(topic_id: topic.id, locale: "es")).to be true
        expect(PostLocalization.exists?(post_id: post.id, locale: "es")).to be true
        expect(PostLocalization.find_by(post_id: post.id, locale: "es").raw).to eq("Hola mundo")
        expect(TopicLocalization.find_by(topic_id: topic.id, locale: "es").title).to eq(
          "Este es un tema de prueba 0",
        )
      end
    end

    it "allows a user to see locales translated" do
      topic_page.visit_topic(topic)
      find("#post_#{post.post_number} .post-action-menu-edit-translations-trigger").click
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
      find("#post_#{post.post_number} .post-action-menu-edit-translations-trigger").click
      find(".post-action-menu__view-translation").click
      find(".post-translations-modal__edit-action .btn").click
      expect(composer).to be_opened
      expect(translation_selector).to have_selected_value("fr")
      find("#translated-topic-title").fill_in(with: "C'est un sujet de test 0.")
      composer.fill_content("Bonjour le monde")
      composer.submit
      post.reload
      topic.reload

      try_until_success do
        expect(TopicLocalization.exists?(topic_id: topic.id, locale: "fr")).to be true
        expect(PostLocalization.exists?(post_id: post.id, locale: "fr")).to be true
        expect(PostLocalization.find_by(post_id: post.id, locale: "fr").raw).to eq(
          "Bonjour le monde",
        )
        expect(TopicLocalization.find_by(topic_id: topic.id, locale: "fr").title).to eq(
          "C'est un sujet de test 0.",
        )
      end
    end

    it "allows a user to delete a translation" do
      topic_page.visit_topic(topic)
      expect(PostLocalization.exists?(post_id: post.id, locale: "fr")).to be true

      find("#post_#{post.post_number} .post-action-menu-edit-translations-trigger").click
      find(".post-action-menu__view-translation").click
      find(".post-translations-modal__delete-action .btn").click
      expect(confirmation_dialog).to be_open
      confirmation_dialog.click_yes

      post.reload
      topic.reload

      try_until_success do
        expect(PostLocalization.exists?(post_id: post.id, locale: "fr")).to be false
      end
    end
  end

  context "when creating a new post in a different locale" do
    it "should only show the languages listed in the site setting and default locale and a none value" do
      visit("/latest")
      page.find("#create-topic").click
      post_language_selector.expand
      expect(post_language_selector).to have_content("English (US)") # default locale
      expect(post_language_selector).to have_content("Français")
      expect(post_language_selector).to have_content("Español")
      expect(post_language_selector).to have_content("Português (BR)")
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

      try_until_success do
        updated_post = Topic.last.posts.first
        expect(updated_post.locale).to eq("fr")
      end
    end

    context "when the user's default locale is different from the site default" do
      before do
        SiteSetting.allow_user_locale = true
        admin.update!(locale: "fr")
      end

      it "should show the user's locale as the default in the post language switcher" do
        visit("/latest")
        page.find("#create-topic").click
        expect(
          page.has_css?("#{POST_LANGUAGE_SWITCHER_SELECTOR} .d-button-label", text: "FR"),
        ).to be true
      end
    end

    context "when the user's default locale is different from the site default but not an available language" do
      before do
        SiteSetting.allow_user_locale = true
        admin.update!(locale: "de")
      end

      it "should make the selected language blank" do
        visit("/latest")
        page.find("#create-topic").click
        expect(page.has_no_css?("#{POST_LANGUAGE_SWITCHER_SELECTOR} .d-button-label")).to be true
      end
    end
  end
end
