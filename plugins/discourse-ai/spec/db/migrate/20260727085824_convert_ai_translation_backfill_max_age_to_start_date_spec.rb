# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/migrate/20260727085824_convert_ai_translation_backfill_max_age_to_start_date",
        )

describe ConvertAiTranslationBackfillMaxAgeToStartDate do
  subject(:migration) { described_class.new }

  let(:connection) { ActiveRecord::Base.connection }

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  before do
    enable_current_plugin
    delete_settings
  end

  after { delete_settings }

  def delete_settings
    connection.execute(<<~SQL)
        DELETE FROM site_settings
        WHERE name IN (
          'discourse_ai_enabled',
          'ai_translation_enabled',
          'ai_translation_backfill_hourly_rate',
          'ai_translation_backfill_max_age_days',
          'ai_translation_backfill_start_date'
        )
      SQL
  end

  def store_setting(name, value, data_type)
    DB.exec(<<~SQL, name:, value:, data_type:)
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES (:name, :data_type, :value, NOW(), NOW())
    SQL
  end

  def configure_backfill(
    discourse_ai_enabled: true,
    ai_translation_enabled: true,
    hourly_rate: 50,
    max_age_days: 30
  )
    unless discourse_ai_enabled.nil?
      store_setting("discourse_ai_enabled", discourse_ai_enabled ? "t" : "f", 5)
    end
    unless ai_translation_enabled.nil?
      store_setting("ai_translation_enabled", ai_translation_enabled ? "t" : "f", 5)
    end
    store_setting("ai_translation_backfill_hourly_rate", hourly_rate, 3) if hourly_rate
    store_setting("ai_translation_backfill_max_age_days", max_age_days, 3) if max_age_days
  end

  def setting(name)
    DB.query("SELECT data_type, value FROM site_settings WHERE name = :name", name:).first
  end

  def utc_date
    DB.query_single("SELECT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date").first
  end

  describe "#up" do
    it "converts a positive max age override to a fixed UTC date" do
      configure_backfill

      expected_start_date = (utc_date - 30).iso8601

      migration.up

      migrated_setting = setting("ai_translation_backfill_start_date")
      expect(migrated_setting.data_type).to eq(33)
      expect(migrated_setting.value).to eq(expected_start_date)
      expect(setting("ai_translation_backfill_max_age_days").value).to eq("30")
    end

    it "uses blank when the max age disables backfilling" do
      configure_backfill(max_age_days: 0)

      migration.up

      expect(setting("ai_translation_backfill_start_date")).to be_nil
      expect(setting("ai_translation_backfill_max_age_days").value).to eq("0")
    end

    it "uses blank when the hourly rate disables backfilling" do
      configure_backfill(hourly_rate: 0)

      migration.up

      expect(setting("ai_translation_backfill_start_date")).to be_nil
    end

    it "uses blank when Discourse AI is disabled" do
      configure_backfill(discourse_ai_enabled: nil)

      migration.up

      expect(setting("ai_translation_backfill_start_date")).to be_nil
    end

    it "uses blank when AI translation is disabled" do
      configure_backfill(ai_translation_enabled: nil)

      migration.up

      expect(setting("ai_translation_backfill_start_date")).to be_nil
    end

    it "converts the previous five-day default when backfilling is enabled" do
      configure_backfill(hourly_rate: nil, max_age_days: nil)

      expected_start_date = (utc_date - 5).iso8601

      migration.up

      migrated_setting = setting("ai_translation_backfill_start_date")
      expect(migrated_setting.data_type).to eq(33)
      expect(migrated_setting.value).to eq(expected_start_date)
    end

    it "keeps an existing start date" do
      configure_backfill
      store_setting("ai_translation_backfill_start_date", "2026-07-01", 33)

      migration.up

      expect(setting("ai_translation_backfill_start_date").value).to eq("2026-07-01")
    end

    it "does not create a start date when no previous settings exist" do
      migration.up

      expect(setting("ai_translation_backfill_start_date")).to be_nil
    end
  end
end
