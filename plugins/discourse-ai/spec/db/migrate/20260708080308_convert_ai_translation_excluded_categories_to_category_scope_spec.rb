# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/migrate/20260708080308_convert_ai_translation_excluded_categories_to_category_scope",
        )

describe ConvertAiTranslationExcludedCategoriesToCategoryScope do
  subject(:migration) { described_class.new }

  let(:connection) { ActiveRecord::Base.connection }

  fab!(:category_1, :category)
  fab!(:category_2, :category)

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  before do
    enable_current_plugin
    delete_settings
  end

  after { delete_settings }

  def delete_settings
    connection.execute(
      "DELETE FROM site_settings WHERE name IN ('ai_translation_excluded_categories', 'ai_translation_enabled', 'ai_translation_category_scope', 'ai_translation_categories')",
    )
  end

  def store_setting(name, val, data_type:)
    connection.execute <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES ('#{name}', #{data_type}, '#{val}', NOW(), NOW())
    SQL
  end

  def setting_value(name)
    DB.query_single("SELECT value FROM site_settings WHERE name = '#{name}'").first
  end

  def setting_exists?(name)
    DB.query_single("SELECT COUNT(*) FROM site_settings WHERE name = '#{name}'").first > 0
  end

  describe "#up" do
    it "converts excluded categories to an exact exclude category scope" do
      store_setting(
        "ai_translation_excluded_categories",
        "#{category_1.id}|#{category_2.id}",
        data_type: 11,
      )

      migration.up

      expect(setting_value("ai_translation_category_scope")).to eq("exclude_strict")
      expect(setting_value("ai_translation_categories")).to eq("#{category_1.id}|#{category_2.id}")
      expect(setting_exists?("ai_translation_excluded_categories")).to eq(false)
    end

    it "preserves all categories for enabled sites with empty excluded categories" do
      store_setting("ai_translation_enabled", "t", data_type: 5)
      store_setting("ai_translation_excluded_categories", "", data_type: 11)

      migration.up

      expect(setting_value("ai_translation_category_scope")).to eq("all")
      expect(setting_value("ai_translation_categories")).to be_nil
      expect(setting_exists?("ai_translation_excluded_categories")).to eq(false)
    end

    it "preserves all categories for enabled sites without stored excluded categories" do
      store_setting("ai_translation_enabled", "t", data_type: 5)

      migration.up

      expect(setting_value("ai_translation_category_scope")).to eq("all")
      expect(setting_value("ai_translation_categories")).to be_nil
    end

    it "uses the public categories default for disabled sites with empty excluded categories" do
      store_setting("ai_translation_enabled", "f", data_type: 5)
      store_setting("ai_translation_excluded_categories", "", data_type: 11)

      migration.up

      expect(setting_value("ai_translation_category_scope")).to be_nil
      expect(setting_value("ai_translation_categories")).to be_nil
      expect(setting_exists?("ai_translation_excluded_categories")).to eq(false)
    end
  end
end
