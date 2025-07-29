# frozen_string_literal: true

describe "Edit Category Localizations", type: :system do
  fab!(:admin)
  fab!(:category) do
    Fabricate(:category, name: "Feature Requests", slug: "feature-requests", topic_count: 1234)
  end
  let(:category_page) { PageObjects::Pages::Category.new }
  let(:form) { PageObjects::Components::FormKit.new("form") }

  before { sign_in(admin) }

  context "when content localization setting is disabled" do
    before { SiteSetting.content_localization_enabled = false }

    it "should not show the localization tab" do
      category_page.visit_settings(category)
      expect(category_page).to have_no_setting_tab("localizations")
    end
  end

  context "when content localization setting is enabled" do
    before do
      SiteSetting.default_locale = "en"
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_supported_locales = "es|fr"
      SiteSetting.content_localization_allowed_groups = Group::AUTO_GROUPS[:everyone]

      if SiteSetting.client_settings.exclude?(:available_content_localization_locales)
        SiteSetting.client_settings << :available_content_localization_locales
      end
    end

    it "should show the localization tab" do
      category_page.visit_settings(category)
      expect(category_page).to have_setting_tab("localizations")
    end

    describe "when editing a category with no category localizations" do
      before { category.update(category_localizations: []) }

      it "should show info hint to add new localizations" do
        category_page.visit_edit_localizations(category)
        expect(form).to have_an_alert(I18n.t("js.category.localization.hint"))
      end

      it "should allow you to add new localizations" do
        category_page.visit_edit_localizations(category)
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
          expect(CategoryLocalization.where(category_id: category.id).count).to eq(2)
        end
        expect(CategoryLocalization.where(category_id: category.id, locale: "es").count).to eq(1)
        expect(CategoryLocalization.where(category_id: category.id, locale: "fr").count).to eq(1)
        expect(CategoryLocalization.where(category_id: category.id, locale: "es").first.name).to eq(
          "Solicitud de función",
        )
        expect(CategoryLocalization.where(category_id: category.id, locale: "fr").first.name).to eq(
          "Demande de fonctionnalité",
        )
        expect(
          CategoryLocalization.where(category_id: category.id, locale: "es").first.description,
        ).to eq("Solicitar nuevas funcionalidades en esta categoría")
        expect(
          CategoryLocalization.where(category_id: category.id, locale: "fr").first.description,
        ).to eq("Demander de nouvelles fonctionnalités dans cette catégorie")
      end
    end

    describe "when editing a category with localizations" do
      fab!(:category_localization) { Fabricate(:category_localization, category:, locale: "es") }

      it "allows you to delete localizations" do
        expect(CategoryLocalization.where(category_id: category.id).count).to eq(1)
        category_page.visit_edit_localizations(category)

        expect(
          category_page.find("#control-localizations-0-locale option.--selected"),
        ).to have_content("Spanish (Español)")

        page.find(".edit-category-tab-localizations .remove-localization").click
        category_page.save_settings
        page.refresh
        try_until_success do
          expect(CategoryLocalization.where(category_id: category.id).count).to eq(0)
        end
      end
    end
  end
end
