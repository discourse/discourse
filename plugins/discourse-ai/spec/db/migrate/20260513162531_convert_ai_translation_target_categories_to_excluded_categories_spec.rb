# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/migrate/20260513162531_convert_ai_translation_target_categories_to_excluded_categories",
        )

RSpec.describe ConvertAiTranslationTargetCategoriesToExcludedCategories do
  subject(:migration) { described_class.new }

  let(:connection) { ActiveRecord::Base.connection }

  fab!(:category_1, :category)
  fab!(:category_2, :category)
  fab!(:category_3, :category)

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  before { enable_current_plugin }

  after do
    connection.execute(
      "DELETE FROM site_settings WHERE name IN ('ai_translation_target_categories', 'ai_translation_excluded_categories')",
    )
  end

  def store_setting(name, val, data_type: 20)
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

  def all_category_ids
    DB.query_single("SELECT id FROM categories").map(&:to_i)
  end

  describe "#up" do
    before { Migration::Helpers.stubs(:existing_site?).returns(true) }

    it "converts target categories to excluded categories for existing sites" do
      store_setting("ai_translation_target_categories", "#{category_1.id}|#{category_3.id}")

      migration.up

      excluded_category_ids =
        setting_value("ai_translation_excluded_categories").split("|").map(&:to_i)
      expect(excluded_category_ids).to contain_exactly(
        *(all_category_ids - [category_1.id, category_3.id]),
      )
      expect(setting_exists?("ai_translation_target_categories")).to eq(false)
    end

    it "excludes all categories for existing sites with an empty target list" do
      store_setting("ai_translation_target_categories", "")

      migration.up

      excluded_category_ids =
        setting_value("ai_translation_excluded_categories").split("|").map(&:to_i)
      expect(excluded_category_ids).to contain_exactly(*all_category_ids)
      expect(setting_exists?("ai_translation_target_categories")).to eq(false)
    end

    it "excludes all categories for existing sites without a stored target list" do
      migration.up

      excluded_category_ids =
        setting_value("ai_translation_excluded_categories").split("|").map(&:to_i)
      expect(excluded_category_ids).to contain_exactly(*all_category_ids)
    end

    it "does not store an excluded list when all existing categories were targets" do
      store_setting("ai_translation_target_categories", all_category_ids.join("|"))

      migration.up

      expect(setting_value("ai_translation_excluded_categories")).to be_nil
      expect(setting_exists?("ai_translation_target_categories")).to eq(false)
    end

    it "does not migrate target categories on new sites" do
      Migration::Helpers.stubs(:existing_site?).returns(false)
      store_setting("ai_translation_target_categories", category_1.id.to_s)

      migration.up

      expect(setting_value("ai_translation_excluded_categories")).to be_nil
      expect(setting_exists?("ai_translation_target_categories")).to eq(false)
    end
  end
end
