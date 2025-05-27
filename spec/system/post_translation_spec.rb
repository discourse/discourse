# frozen_string_literal: true

describe "Post translations", type: :system do
  fab!(:user)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, user: user) }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:translation_selector) do
    PageObjects::Components::SelectKit.new(".translation-selector-dropdown")
  end
  let(:view_translations_modal) { PageObjects::Modals::ViewTranslationsModal.new }

  before do
    sign_in(user)
    SiteSetting.experimental_content_localization_supported_locales = "en|fr|es|pt_BR"
    SiteSetting.experimental_content_localization = true
    SiteSetting.experimental_content_localization_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.post_menu =
      "read|like|copyLink|flag|edit|bookmark|delete|admin|reply|addTranslation"
  end

  context "when a post does not have translations" do
    it "should only show the languages listed in the site setting" do
      topic_page.visit_topic(topic)
      find("#post_#{post.post_number} .post-action-menu__add-translation").click
      translation_selector.expand
      expect(all(".translation-selector-dropdown .select-kit-collection li").count).to eq(4)
      expect(translation_selector).to have_option_value("en")
      expect(translation_selector).to have_option_value("fr")
      expect(translation_selector).to have_option_value("es")
      expect(translation_selector).to have_option_value("pt_BR")
      expect(translation_selector).to have_no_option_value("de")
    end

    it "always includes the site's default locale in the list of available languages" do
      SiteSetting.default_locale = "de"
      topic_page.visit_topic(topic)
      find("#post_#{post.post_number} .post-action-menu__add-translation").click
      translation_selector.expand
      expect(all(".translation-selector-dropdown .select-kit-collection li").count).to eq(5)
      expect(translation_selector).to have_option_value("de")
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

    it "allows a user to add a new translation" do
      topic_page.visit_topic(topic)
      find("#post_#{post.post_number} .post-action-menu-edit-translations-trigger").click
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

      post.reload
      topic.reload

      try_until_success do
        expect(PostLocalization.exists?(post_id: post.id, locale: "fr")).to be false
      end
    end
  end
end
