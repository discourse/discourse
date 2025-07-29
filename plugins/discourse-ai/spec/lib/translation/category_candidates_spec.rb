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
        locale = "es"
        Fabricate(:category, locale:)
        Category.update_all(locale: locale)

        completion = DiscourseAi::Translation::CategoryCandidates.get_completion_per_locale(locale)
        expect(completion).to eq(1.0)
      end

      it "returns X% completion if some categories are in the locale" do
        locale = "es"
        Fabricate(:category, locale:)

        completion = DiscourseAi::Translation::CategoryCandidates.get_completion_per_locale(locale)
        expect(completion).to eq(1 / Category.count.to_f)
      end
    end

    context "when (scenario B) percentage determined by category localizations" do
      it "returns 100% completion if all categories have a localization in the locale" do
        locale = "es"
        Fabricate(:category)
        Category.all.each { |category| Fabricate(:category_localization, category:, locale:) }

        completion = DiscourseAi::Translation::CategoryCandidates.get_completion_per_locale(locale)
        expect(completion).to eq(1.0)
      end

      it "returns X% completion if some categories have a localization in the locale" do
        locale = "es"
        cat = Fabricate(:category)
        Fabricate(:category_localization, category: cat, locale:)

        completion = DiscourseAi::Translation::CategoryCandidates.get_completion_per_locale(locale)
        expect(completion).to eq(1 / Category.count.to_f)
      end
    end

    it "returns the correct percentage based on (scenario A & B) `category.locale` and `CategoryLocalization` in the specified locale" do
      locale = "es"
      Fabricate(:category, locale:)
      cat = Fabricate(:category)
      Fabricate(:category_localization, category: cat, locale:)

      completion = DiscourseAi::Translation::CategoryCandidates.get_completion_per_locale(locale)
      expect(completion).to eq(2 / Category.count.to_f)
    end
  end
end
