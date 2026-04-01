# frozen_string_literal: true

describe DiscourseAi::Translation::CategoryCandidates do
  describe ".get" do
    it "returns only target categories when target_categories is set" do
      target = Fabricate(:category)
      non_target = Fabricate(:category)
      SiteSetting.ai_translation_target_categories = target.id.to_s

      categories = DiscourseAi::Translation::CategoryCandidates.get
      expect(categories).to include(target)
      expect(categories).not_to include(non_target)
    end

    it "returns no categories when target_categories is empty" do
      Fabricate(:category)

      SiteSetting.ai_translation_target_categories = ""
      expect(DiscourseAi::Translation::CategoryCandidates.get.count).to eq(0)
    end
  end

  describe ".calculate_completion_per_locale" do
    fab!(:target_category, :category)

    before { SiteSetting.ai_translation_target_categories = target_category.id.to_s }

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
        SiteSetting.ai_translation_target_categories = "#{target_category.id}|#{target2.id}"
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
        SiteSetting.ai_translation_target_categories = "#{target_category.id}|#{target2.id}"
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
      SiteSetting.ai_translation_target_categories = ""

      completion =
        DiscourseAi::Translation::CategoryCandidates.calculate_completion_per_locale("pt")
      expect(completion).to eq({ done: 0, total: 0 })
    end
  end
end
