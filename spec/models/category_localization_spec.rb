# frozen_string_literal: true

describe CategoryLocalization do
  describe "#description_first_paragraph" do
    it "cooks the description and keeps only the first paragraph" do
      localization =
        Fabricate(
          :category_localization,
          description: "un [enlace](https://example.com)\n\notro párrafo",
        )

      expect(localization.description_first_paragraph).to eq(
        "un <a href=\"https://example.com\" rel=\"noopener nofollow ugc\">enlace</a>",
      )
    end

    it "returns nil when the cooked description has no paragraph" do
      localization = Fabricate(:category_localization, description: "- uno\n- dos")

      expect(localization.description_first_paragraph).to be_nil
    end
  end

  describe "#description_text and #description_excerpt" do
    it "derives plain text and excerpt from the first paragraph" do
      localization = Fabricate(:category_localization, description: "un **texto**\n\notro párrafo")

      expect(localization.description_text).to eq("un texto")
      expect(localization.description_excerpt).to eq("un texto")
    end

    it "returns nil when there is no first paragraph" do
      localization = Fabricate(:category_localization, description: "- uno\n- dos")

      expect(localization.description_text).to be_nil
      expect(localization.description_excerpt).to be_nil
    end
  end

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
