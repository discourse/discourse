# frozen_string_literal: true

describe CategoryLocalization do
  context "when commit" do
    it "clears the site cache for the locale" do
      category = Fabricate(:category, name: "yy")

      I18n.locale = "es"
      expect(Site.all_categories_cache.pluck(:name)).to include("yy")

      I18n.locale = "en"
      expect(Site.all_categories_cache.pluck(:name)).to include("yy")

      category.update_columns(name: "zz")

      I18n.locale = "es"
      expect(Site.all_categories_cache.pluck(:name)).to include("yy")
      I18n.locale = "en"
      expect(Site.all_categories_cache.pluck(:name)).to include("yy")

      Fabricate(:category_localization, name: "Japón", locale: "es", category:)

      I18n.locale = "es"
      expect(Site.all_categories_cache.pluck(:name)).to include("zz")
      I18n.locale = "en"
      expect(Site.all_categories_cache.pluck(:name)).to include("yy")
    end
  end
end
