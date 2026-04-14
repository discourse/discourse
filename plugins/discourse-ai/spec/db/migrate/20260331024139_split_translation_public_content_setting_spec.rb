# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/migrate/20260331024139_split_translation_public_content_setting",
        )

RSpec.describe SplitTranslationPublicContentSetting do
  subject(:migration) { described_class.new }

  let(:connection) { ActiveRecord::Base.connection }

  def store_setting(name, val, data_type: 3)
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

  fab!(:public_category) { Fabricate(:category, read_restricted: false) }
  fab!(:private_category) { Fabricate(:category, read_restricted: true) }

  before { enable_current_plugin }

  after do
    connection.execute(
      "DELETE FROM site_settings WHERE name IN ('ai_translation_target_categories', 'ai_translation_personal_messages', 'ai_translation_backfill_limit_to_public_content', 'ai_translation_enabled')",
    )
  end

  describe "#up" do
    context "when old setting was false and translation is enabled" do
      before do
        store_setting("ai_translation_enabled", "t")
        store_setting("ai_translation_backfill_limit_to_public_content", "f")
      end

      it "sets target_categories to all categories and private_messages to all" do
        migration.up

        category_ids = setting_value("ai_translation_target_categories").split("|").map(&:to_i)
        expect(category_ids).to include(public_category.id, private_category.id)
        expect(setting_value("ai_translation_personal_messages")).to eq("all")
        expect(setting_exists?("ai_translation_backfill_limit_to_public_content")).to eq(false)
      end
    end

    context "when old setting was false and translation is disabled" do
      before { store_setting("ai_translation_backfill_limit_to_public_content", "f") }

      it "still migrates settings and deletes the old setting" do
        migration.up

        category_ids = setting_value("ai_translation_target_categories").split("|").map(&:to_i)
        expect(category_ids).to include(public_category.id, private_category.id)
        expect(setting_value("ai_translation_personal_messages")).to eq("all")
        expect(setting_exists?("ai_translation_backfill_limit_to_public_content")).to eq(false)
      end
    end

    context "when old setting was default (absent) and translation is enabled" do
      before { store_setting("ai_translation_enabled", "t") }

      it "sets target_categories to public categories only" do
        migration.up

        category_ids = setting_value("ai_translation_target_categories").split("|").map(&:to_i)
        expect(category_ids).to include(public_category.id)
        expect(category_ids).not_to include(private_category.id)
        expect(setting_value("ai_translation_personal_messages")).to be_nil
        expect(setting_exists?("ai_translation_backfill_limit_to_public_content")).to eq(false)
      end
    end

    context "when translation was never used" do
      it "inserts nothing and deletes the old setting if present" do
        store_setting("ai_translation_backfill_limit_to_public_content", "t")

        migration.up

        expect(setting_value("ai_translation_target_categories")).to be_nil
        expect(setting_value("ai_translation_personal_messages")).to be_nil
        expect(setting_exists?("ai_translation_backfill_limit_to_public_content")).to eq(false)
      end
    end

    context "when no settings exist at all" do
      it "does nothing" do
        migration.up

        expect(setting_value("ai_translation_target_categories")).to be_nil
        expect(setting_value("ai_translation_personal_messages")).to be_nil
      end
    end
  end
end
