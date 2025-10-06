# frozen_string_literal: true

describe "Category Localizations", type: :system do
  SWITCHER_SELECTOR = "button[data-identifier='language-switcher']"

  fab!(:admin)
  fab!(:category) do
    Fabricate(
      :category,
      name: "Feature Requests",
      slug: "feature-requests",
      topic_count: 1234,
      subcategory_list_style: "boxes",
      show_subcategory_list: true,
    )
  end
  let(:category_page) { PageObjects::Pages::Category.new }
  let(:form) { PageObjects::Components::FormKit.new("form") }
  let(:switcher) { PageObjects::Components::DMenu.new(SWITCHER_SELECTOR) }

  before do
    SiteSetting.content_localization_supported_locales = "es|ja|fr"
    SiteSetting.content_localization_enabled = true
    SiteSetting.allow_user_locale = true
    SiteSetting.set_locale_from_cookie = true
    SiteSetting.desktop_category_page_style = "categories_boxes"
  end

  context "when content localization setting is disabled" do
    before { SiteSetting.content_localization_enabled = false }

    it "should not show the localization tab" do
      sign_in(admin)

      category_page.visit_settings(category)
      expect(category_page).to have_no_setting_tab("localizations")
    end
  end

  context "when content localization setting is enabled" do
    fab!(:category_localization) { Fabricate(:category_localization, category:, locale: "ja") }
    fab!(:category_localization) do
      Fabricate(
        :category_localization,
        category:,
        locale: "es",
        name: "Solicitudes",
        description: "Discusiones sobre las solicitudes de todos los gatos",
      )
    end

    before do
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_allowed_groups = Group::AUTO_GROUPS[:everyone]

      if SiteSetting.client_settings.exclude?(:available_content_localization_locales)
        SiteSetting.client_settings << :available_content_localization_locales
      end
    end

    describe "Category Settings" do
      before { sign_in(admin) }

      it "should show the localization tab" do
        category_page.visit_settings(category)
        expect(category_page).to have_setting_tab("localizations")
      end

      describe "when editing a category with no category localizations" do
        fab!(:mono_category, :category)

        it "should show info hint to add new localizations" do
          category_page.visit_edit_localizations(mono_category)
          expect(form).to have_an_alert(I18n.t("js.category.localization.hint"))
        end

        it "should allow you to add new localizations" do
          category_page.visit_edit_localizations(mono_category)
          category_page.find(".edit-category-tab-localizations .add-localization").click
          form.field("localizations.0.locale").select("es")
          form.field("localizations.0.name").fill_in("Solicitud de función")
          form.field("localizations.0.description").fill_in(
            "Solicitar nuevas funcionalidades en esta categoría",
          )
          category_page.find(".edit-category-tab-localizations .add-localization").click
          form.field("localizations.1.locale").select("fr")
          form.field("localizations.1.name").fill_in("Demande de fonctionnalité")
          form.field("localizations.1.description").fill_in(
            "Demander de nouvelles fonctionnalités dans cette catégorie",
          )
          category_page.save_settings
          page.refresh

          try_until_success do
            expect(CategoryLocalization.where(category_id: mono_category.id).count).to eq(2)
          end
          expect(
            CategoryLocalization.where(category_id: mono_category.id, locale: "es").count,
          ).to eq(1)
          expect(
            CategoryLocalization.where(category_id: mono_category.id, locale: "fr").count,
          ).to eq(1)
          expect(
            CategoryLocalization.where(category_id: mono_category.id, locale: "es").first.name,
          ).to eq("Solicitud de función")
          expect(
            CategoryLocalization.where(category_id: mono_category.id, locale: "fr").first.name,
          ).to eq("Demande de fonctionnalité")
          expect(
            CategoryLocalization
              .where(category_id: mono_category.id, locale: "es")
              .first
              .description,
          ).to eq("Solicitar nuevas funcionalidades en esta categoría")
          expect(
            CategoryLocalization
              .where(category_id: mono_category.id, locale: "fr")
              .first
              .description,
          ).to eq("Demander de nouvelles fonctionnalités dans cette catégorie")
        end
      end

      describe "when editing a category with localizations" do
        it "allows you to delete localizations" do
          expect(CategoryLocalization.where(category_id: category.id).count).to eq(2)
          category_page.visit_edit_localizations(category)

          expect(category_page).to have_selector(
            ".edit-category-tab-localizations .form-kit__collection .form-kit__row",
            count: 2,
          )
          expect(
            category_page.find("#control-localizations-0-locale option.--selected"),
          ).to have_content("Spanish (Español)")
          expect(
            category_page.find("#control-localizations-1-locale option.--selected"),
          ).to have_content("Japanese (日本語)")

          page.find(".edit-category-tab-localizations .remove-localization", match: :first).click
          category_page.save_settings
          page.refresh

          expect(category_page).to_not have_css("#control-localizations-0-locale option.--selected")
          expect(
            category_page.find("#control-localizations-0-locale option.--selected"),
          ).to have_content("Japanese (日本語)")
        end
      end
    end

    describe "Navigating categories" do
      let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }
      let(:topic_list) { PageObjects::Components::TopicList.new }
      let(:category_list) { PageObjects::Components::CategoryList.new }

      fab!(:cat_topic) { Fabricate(:topic, category:) }
      fab!(:subcat) do
        Fabricate(
          :category,
          name: "Subcategory",
          description: "A",
          parent_category: category,
        ).tap do |category|
          Fabricate(
            :category_localization,
            category:,
            locale: "es",
            name: "Subcategoría",
            description: "Una subcategoría de un padre",
          )
        end
      end
      fab!(:subcat_topic) { Fabricate(:topic, category: subcat) }

      before { SiteSetting.content_localization_language_switcher = "all" }

      describe "for anonymous users" do
        it "keeps the translated category name when navigating sidebar" do
          visit("/")
          switcher.expand
          switcher.option("[data-menu-option-id='es']").click

          expect(sidebar).to have_section_link("Solicitudes")
          sidebar.click_section_link("Solicitudes")

          category_dropdown = PageObjects::Components::SelectKit.new(".category-drop")
          expect(category_dropdown).to have_selected_name("Solicitudes")
          expect(category_page.category_box(subcat)).to have_text("Subcategoría")
          expect(category_page.category_box(subcat)).to have_text("Una subcategoría de un padre")
          expect(topic_list.topic(cat_topic)).to have_text("Solicitudes")
          expect(topic_list.topic(subcat_topic)).to have_text("Subcategoría")

          category_page.category_box(subcat).click

          parent_category_dropdown =
            PageObjects::Components::SelectKit.new(
              ".category-breadcrumb li:nth-child(1) .category-drop",
            )
          sub_category_dropdown =
            PageObjects::Components::SelectKit.new(
              ".category-breadcrumb li:nth-child(2) .category-drop",
            )
          expect(parent_category_dropdown).to have_selected_name("Solicitudes")
          expect(sub_category_dropdown).to have_selected_name("Subcategoría")
        end

        it "keeps the translated category name when navigating topic filters" do
          visit("/categories")
          switcher.expand
          switcher.option("[data-menu-option-id='es']").click

          expect(category_list.category_box(category)).to have_text("Solicitudes")

          category_list.category_box(category).click
          category_dropdown = PageObjects::Components::SelectKit.new(".category-drop")
          expect(category_dropdown).to have_selected_name("Solicitudes")
          expect(sidebar).to have_section_link("Solicitudes")
          expect(category_page.category_box(subcat)).to have_text("Subcategoría")

          sidebar.click_topics_button

          expect(topic_list.topic(cat_topic)).to have_text("Solicitudes")
        end
      end
    end
  end
end
