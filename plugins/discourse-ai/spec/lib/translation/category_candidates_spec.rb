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
    context "when (scenario A) percentage determined by category's locale" do
      it "returns 100% completion if all categories are in the locale" do
        locale = "pt_BR"
        Fabricate(:category, locale:)
        Category.update_all(locale: locale)
        Fabricate(:category, locale: "pt")

        completion = DiscourseAi::Translation::CategoryCandidates.get_completion_per_locale(locale)
        expect(completion).to eq(1.0)
      end

      it "returns X% completion if some categories are in the locale" do
        locale = "pt_BR"
        Fabricate(:category, locale:)
        Fabricate(:category, locale: "not_pt")

        completion = DiscourseAi::Translation::CategoryCandidates.get_completion_per_locale(locale)
        expect(completion).to eq(1 / Category.count.to_f)
      end
    end

    context "when (scenario B) percentage determined by category localizations" do
      it "returns 100% completion if all categories have a localization in the locale" do
        locale = "pt_BR"
        Fabricate(:category)
        Category.all.each { |category| Fabricate(:category_localization, category:, locale:) }
        Fabricate(:category_localization, locale: "pt")

        completion = DiscourseAi::Translation::CategoryCandidates.get_completion_per_locale(locale)
        expect(completion).to eq(1.0)
      end

      it "returns X% completion if some categories have a localization in the locale" do
        locale = "es"
        Fabricate(:category_localization, locale:)
        Fabricate(:category_localization, locale: "pt")

        completion = DiscourseAi::Translation::CategoryCandidates.get_completion_per_locale(locale)
        expect(completion).to eq(1 / Category.count.to_f)
      end
    end

    it "returns the correct percentage based on (scenario A & B) `category.locale` and `CategoryLocalization` in the specified locale" do
      locale = "pt_BR"

      # translated candidates
      Fabricate(:category, locale:)
      category2 = Fabricate(:category)
      Fabricate(:category_localization, category: category2, locale:)

      # untranslated candidate
      category3 = Fabricate(:category)
      Fabricate(:category_localization, category: category3, locale: "zh_CN")

      # not a candidate as it is read restricted
      SiteSetting.ai_translation_backfill_limit_to_public_content = true
      category4 = Fabricate(:category, read_restricted: true)
      Fabricate(:category_localization, category: category4, locale:)

      completion = DiscourseAi::Translation::CategoryCandidates.get_completion_per_locale(locale)
      translated_candidates = 2 # category1 + category2
      total_candidates = Category.count - 1 # excluding the read restricted category
      expect(completion).to eq(translated_candidates / total_candidates.to_f)
    end

    it "does not exceed 100% completion when category.locale and category_localization both exist" do
      locale = "pt_BR"
      Category.update_all(locale:)
      category = Fabricate(:category, locale:)
      Fabricate(:category_localization, category:, locale:)

      completion = DiscourseAi::Translation::CategoryCandidates.get_completion_per_locale(locale)
      expect(completion).to be(1.0)
    end

    it "returns 100% completion when there are no categories" do
      SiteSetting.ai_translation_backfill_limit_to_public_content = false
      Category.destroy_all

      completion = DiscourseAi::Translation::CategoryCandidates.get_completion_per_locale("pt")
      expect(completion).to eq(1.0)
    end
  end
end
