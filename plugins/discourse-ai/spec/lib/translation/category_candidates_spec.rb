# frozen_string_literal: true

describe DiscourseAi::Translation::CategoryCandidates do
  describe ".get" do
    it "returns all categories" do
      expect(DiscourseAi::Translation::CategoryCandidates.get.count).to eq(Category.count)
    end

    it "filters out read restricted categories if ai_translation_backfill_limit_to_public_content is enabled" do
      SiteSetting.ai_translation_backfill_limit_to_public_content = true
      restricted_category = Fabricate(:category, read_restricted: true)
      public_category = Fabricate(:category, read_restricted: false)

      categories = DiscourseAi::Translation::CategoryCandidates.get
      expect(categories).not_to include(restricted_category)
      expect(categories).to include(public_category)
    end
  end

  describe ".get_completion_per_locale" do
    context "when (scenario A) completion determined by category's locale" do
      it "returns done = total if all categories are in the locale" do
        locale = "pt_BR"
        Fabricate(:category, locale:)
        Category.update_all(locale: locale)
        Fabricate(:category, locale: "pt") # pt counts as pt_BR

        completion = DiscourseAi::Translation::CategoryCandidates.get_completion_per_locale(locale)
        expect(completion).to eq({ done: Category.count, total: Category.count })
      end

      it "returns correct done and total if some categories are in the locale" do
        locale = "pt_BR"
        Category.update_all(locale: "ar") # not portuguese

        Fabricate(:category, locale:)
        Fabricate(:category, locale: "ar") # not portuguese

        completion = DiscourseAi::Translation::CategoryCandidates.get_completion_per_locale(locale)
        expect(completion).to eq({ done: 1, total: Category.count })
      end
    end

    context "when (scenario B) completion determined by category localizations" do
      it "returns done = total if all categories have a localization in the locale" do
        locale = "pt_BR"

        Fabricate(:category, locale: "en")
        Category.all.each do |category|
          category.update(locale: "en")
          Fabricate(:category_localization, category:, locale:)
        end
        CategoryLocalization.order("RANDOM()").first.update(locale: "pt") # pt counts as pt_BR

        completion = DiscourseAi::Translation::CategoryCandidates.get_completion_per_locale(locale)
        expect(completion).to eq({ done: Category.count, total: Category.count })
      end

      it "returns correct done and total if some categories have a localization in the locale" do
        locale = "es"
        category1 = Fabricate(:category, locale: "en")
        category2 = Fabricate(:category, locale: "fr")
        Fabricate(:category_localization, category: category1, locale:)
        Fabricate(:category_localization, category: category2, locale: "ar") # not the target locale

        completion = DiscourseAi::Translation::CategoryCandidates.get_completion_per_locale(locale)
        categories_with_locale = Category.where.not(locale: nil).count
        expect(completion).to eq({ done: 1, total: categories_with_locale })
      end
    end

    it "returns the correct done and total based on (scenario A & B) `category.locale` and `CategoryLocalization` in the specified locale" do
      locale = "pt_BR"

      Category.update_all(locale: "en")

      # translated candidates
      Fabricate(:category, locale:)
      category2 = Fabricate(:category, locale: "en")
      Fabricate(:category_localization, category: category2, locale:)

      # untranslated candidate
      category3 = Fabricate(:category, locale: "fr")
      Fabricate(:category_localization, category: category3, locale: "zh_CN")

      # not a candidate as it is read restricted
      SiteSetting.ai_translation_backfill_limit_to_public_content = true
      category4 = Fabricate(:category, read_restricted: true, locale: "de")
      Fabricate(:category_localization, category: category4, locale:)

      completion = DiscourseAi::Translation::CategoryCandidates.get_completion_per_locale(locale)
      translated_candidates = 2 # category1 + category2
      total_candidates = Category.count - 1 # excluding the read restricted category
      expect(completion).to eq({ done: translated_candidates, total: total_candidates })
    end

    it "does not allow done to exceed total when category.locale and category_localization both exist" do
      locale = "pt_BR"
      Category.update_all(locale:)
      category = Fabricate(:category, locale:)
      Fabricate(:category_localization, category:, locale:)

      completion = DiscourseAi::Translation::CategoryCandidates.get_completion_per_locale(locale)
      expect(completion).to eq({ done: Category.count, total: Category.count })
    end

    it "returns nil - nil for done and total when no categories are present" do
      SiteSetting.ai_translation_backfill_limit_to_public_content = false
      Category.destroy_all

      completion = DiscourseAi::Translation::CategoryCandidates.get_completion_per_locale("pt")
      expect(completion).to eq({ done: 0, total: 0 })
    end
  end
end
