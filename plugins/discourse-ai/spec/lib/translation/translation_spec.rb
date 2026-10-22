# frozen_string_literal: true

describe DiscourseAi::Translation do
  before do
    assign_fake_provider_to(:ai_default_llm_model)
    enable_current_plugin
    SiteSetting.ai_translation_enabled = true
    SiteSetting.ai_translation_category_scope = "all"
    SiteSetting.ai_translation_categories = ""
  end

  describe ".locales" do
    it "delegates to SiteSetting.content_localization_locales" do
      SiteSetting.content_localization_supported_locales = "es|fr"
      SiteSetting.default_locale = "en"

      expect(described_class.locales).to eq(SiteSetting.content_localization_locales)
    end
  end

  describe ".backfill_start_at" do
    it "returns midnight UTC on the configured date" do
      SiteSetting.ai_translation_backfill_start_date = "2026-07-01"

      expect(described_class.backfill_start_at.iso8601).to eq("2026-07-01T00:00:00Z")
    end
  end

  describe ".backfill_enabled?" do
    it "uses the start date only for post and topic backfills" do
      SiteSetting.content_localization_supported_locales = "es"
      SiteSetting.ai_translation_backfill_hourly_rate = 50
      SiteSetting.ai_translation_backfill_start_date = ""

      expect(described_class.backfill_enabled?).to eq(true)
      expect(described_class.backfill_enabled?(target: Category)).to eq(true)
      expect(described_class.backfill_enabled?(target: Post)).to eq(false)
      expect(described_class.backfill_enabled?(target: Topic)).to eq(false)

      SiteSetting.ai_translation_backfill_start_date = "2026-07-01"

      expect(described_class.backfill_enabled?(target: Post)).to eq(true)
      expect(described_class.backfill_enabled?(target: Topic)).to eq(true)
    end
  end

  describe ".supported_locale_bases_cte" do
    it "normalizes and deduplicates supported locale bases" do
      sql = <<~SQL
        WITH #{described_class.supported_locale_bases_cte}
        SELECT bases
        FROM supported
      SQL

      result = DB.query_single(sql, supported_locales: %w[en_GB EN-us pt-BR])

      expect(result.first).to contain_exactly("en", "pt")
    end
  end

  describe ".category_scope_condition" do
    it "filters categories for all and public scopes", :aggregate_failures do
      public_category = Fabricate(:category)
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      categories = Category.where(id: [public_category.id, private_category.id])

      SiteSetting.ai_translation_category_scope = "all"
      sql, params = described_class.category_scope_condition(category_column: "categories.id")
      expect(categories.where(sql, params)).to contain_exactly(public_category, private_category)

      SiteSetting.ai_translation_category_scope = "public"
      sql, params = described_class.category_scope_condition(category_column: "categories.id")
      expect(categories.where(sql, params)).to contain_exactly(public_category)
    end

    it "filters categories with selected category scopes", :aggregate_failures do
      parent_category = Fabricate(:category)
      subcategory = Fabricate(:category, parent_category:)
      unselected_category = Fabricate(:category)
      categories = Category.where(id: [parent_category.id, subcategory.id, unselected_category.id])

      SiteSetting.ai_translation_category_scope = "include"
      SiteSetting.ai_translation_categories = parent_category.id.to_s
      sql, params = described_class.category_scope_condition(category_column: "categories.id")
      expect(categories.where(sql, params)).to contain_exactly(parent_category, subcategory)

      SiteSetting.ai_translation_category_scope = "include_strict"
      sql, params = described_class.category_scope_condition(category_column: "categories.id")
      expect(categories.where(sql, params)).to contain_exactly(parent_category)

      SiteSetting.ai_translation_category_scope = "exclude"
      sql, params = described_class.category_scope_condition(category_column: "categories.id")
      expect(categories.where(sql, params)).to contain_exactly(unselected_category)

      SiteSetting.ai_translation_category_scope = "exclude_strict"
      sql, params = described_class.category_scope_condition(category_column: "categories.id")
      expect(categories.where(sql, params)).to contain_exactly(subcategory, unselected_category)
    end
  end

  describe ".category_allowed?" do
    it "allows categories according to the configured scope", :aggregate_failures do
      parent_category = Fabricate(:category)
      subcategory = Fabricate(:category, parent_category:)
      private_category = Fabricate(:private_category, group: Fabricate(:group))

      SiteSetting.ai_translation_category_scope = "include"
      SiteSetting.ai_translation_categories = parent_category.id.to_s
      expect(described_class.category_allowed?(subcategory)).to eq(true)

      SiteSetting.ai_translation_category_scope = "include_strict"
      expect(described_class.category_allowed?(subcategory)).to eq(false)

      SiteSetting.ai_translation_category_scope = "public"
      expect(described_class.category_allowed?(private_category.id)).to eq(false)
    end
  end

  describe ".post_localization_pending?" do
    fab!(:post)

    before do
      SiteSetting.content_localization_supported_locales = "en|ja"
      freeze_time
    end

    it "is true while the post's locale hasn't been detected" do
      expect(described_class.post_localization_pending?(post, "ja")).to eq(true)
    end

    it "is true until the translation into the locale is stored" do
      post.update_columns(locale: "en")
      expect(described_class.post_localization_pending?(post, "ja")).to eq(true)

      Fabricate(:post_localization, post: post, locale: "ja")
      expect(described_class.post_localization_pending?(post.reload, "ja")).to eq(false)
    end

    it "is false when the post is already in the locale" do
      post.update_columns(locale: "ja")
      expect(described_class.post_localization_pending?(post, "ja")).to eq(false)
    end

    it "is false for locales that aren't translated into" do
      expect(described_class.post_localization_pending?(post, "fr")).to eq(false)
    end

    it "is false for older posts" do
      post.update_columns(created_at: (described_class::PENDING_LOCALIZATION_WINDOW + 1.minute).ago)
      expect(described_class.post_localization_pending?(post, "ja")).to eq(false)
    end

    it "is false for posts that aren't translated automatically" do
      SiteSetting.ai_translation_category_scope = "exclude_strict"
      SiteSetting.ai_translation_categories = post.topic.category_id.to_s
      expect(described_class.post_localization_pending?(post, "ja")).to eq(false)
    end

    it "is false when translation is disabled" do
      SiteSetting.ai_translation_enabled = false
      expect(described_class.post_localization_pending?(post, "ja")).to eq(false)
    end
  end
end
