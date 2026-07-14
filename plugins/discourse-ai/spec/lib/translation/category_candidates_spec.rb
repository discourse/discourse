# frozen_string_literal: true

describe DiscourseAi::Translation::CategoryCandidates do
  describe ".get" do
    before do
      SiteSetting.ai_translation_category_scope = "all"
      SiteSetting.ai_translation_categories = ""
    end

    it "returns all categories when all categories are configured" do
      category_1 = Fabricate(:category)
      category_2 = Fabricate(:category)

      categories = DiscourseAi::Translation::CategoryCandidates.get
      expect(categories).to include(category_1, category_2)
    end

    it "returns private categories by default" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))

      expect(DiscourseAi::Translation::CategoryCandidates.get).to include(private_category)
    end

    it "returns only public categories when configured" do
      public_category = Fabricate(:category)
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      SiteSetting.ai_translation_category_scope = "public"

      categories = DiscourseAi::Translation::CategoryCandidates.get
      expect(categories).to include(public_category)
      expect(categories).not_to include(private_category)
    end

    it "includes selected categories and subcategories" do
      parent_category = Fabricate(:category)
      subcategory = Fabricate(:category, parent_category:)
      unselected_category = Fabricate(:category)
      SiteSetting.ai_translation_category_scope = "include"
      SiteSetting.ai_translation_categories = parent_category.id.to_s

      categories = DiscourseAi::Translation::CategoryCandidates.get
      expect(categories).to include(parent_category, subcategory)
      expect(categories).not_to include(unselected_category)
    end

    it "excludes only selected categories in strict mode" do
      parent_category = Fabricate(:category)
      subcategory = Fabricate(:category, parent_category:)
      SiteSetting.ai_translation_category_scope = "exclude_strict"
      SiteSetting.ai_translation_categories = parent_category.id.to_s

      categories = DiscourseAi::Translation::CategoryCandidates.get
      expect(categories).to include(subcategory)
      expect(categories).not_to include(parent_category)
    end
  end

  describe ".calculate_completion_per_locale" do
    fab!(:target_category, :category)

    before do
      SiteSetting.ai_translation_category_scope = "all"
      SiteSetting.ai_translation_categories = ""
    end

    context "when (scenario A) completion determined by category's locale" do
      it "returns done = total if all categories are in the locale" do
        locale = "pt_BR"
        target_category.update!(locale: locale)

        completion =
          DiscourseAi::Translation::CategoryCandidates.calculate_completion_per_locale(locale)
        expect(completion).to eq({ done: 1, total: 1 })
      end

      it "returns correct done and total if some categories are in the locale" do
        locale = "pt_BR"
        target2 = Fabricate(:category, locale: "ar")
        target_category.update!(locale: locale)

        completion =
          DiscourseAi::Translation::CategoryCandidates.calculate_completion_per_locale(locale)
        expect(completion).to eq({ done: 1, total: 2 })
      end
    end

    context "when (scenario B) completion determined by category localizations" do
      it "returns done = total if all categories have a localization in the locale" do
        locale = "pt_BR"
        target_category.update!(locale: "en")
        Fabricate(:category_localization, category: target_category, locale:)

        completion =
          DiscourseAi::Translation::CategoryCandidates.calculate_completion_per_locale(locale)
        expect(completion).to eq({ done: 1, total: 1 })
      end

      it "returns correct done and total if some categories have a localization in the locale" do
        locale = "es"
        target2 = Fabricate(:category, locale: "fr")
        target_category.update!(locale: "en")
        Fabricate(:category_localization, category: target_category, locale:)
        Fabricate(:category_localization, category: target2, locale: "ar")

        completion =
          DiscourseAi::Translation::CategoryCandidates.calculate_completion_per_locale(locale)
        expect(completion).to eq({ done: 1, total: 2 })
      end
    end

    it "does not allow done to exceed total when category.locale and category_localization both exist" do
      locale = "pt_BR"
      target_category.update!(locale:)
      Fabricate(:category_localization, category: target_category, locale:)

      completion =
        DiscourseAi::Translation::CategoryCandidates.calculate_completion_per_locale(locale)
      expect(completion).to eq({ done: 1, total: 1 })
    end

    it "returns 0 for done and total when no categories match" do
      SiteSetting.ai_translation_category_scope = "include"
      SiteSetting.ai_translation_categories = ""

      completion =
        DiscourseAi::Translation::CategoryCandidates.calculate_completion_per_locale("pt")
      expect(completion).to eq({ done: 0, total: 0 })
    end
  end
end
