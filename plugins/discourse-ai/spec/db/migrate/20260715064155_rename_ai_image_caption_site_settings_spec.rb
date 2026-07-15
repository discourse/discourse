# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/migrate/20260715064155_rename_ai_image_caption_site_settings",
        )

describe RenameAiImageCaptionSiteSettings do
  subject(:migration) { described_class.new }

  let(:connection) { ActiveRecord::Base.connection }

  SETTINGS = %w[
    ai_helper_image_caption_agent
    ai_image_caption_agent
    ai_post_image_descriptions_enabled
    ai_post_image_captions_enabled
    ai_post_image_descriptions_per_post_limit
    ai_post_image_captions_per_post_limit
    ai_post_image_descriptions_backfill_hourly_rate
    ai_post_image_captions_backfill_hourly_rate
    ai_post_image_descriptions_backfill_max_age_days
    ai_post_image_captions_backfill_max_age_days
  ].freeze

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  before { delete_settings }

  after { delete_settings }

  def delete_settings
    quoted_names = SETTINGS.map { |name| connection.quote(name) }.join(", ")
    connection.execute("DELETE FROM site_settings WHERE name IN (#{quoted_names})")
  end

  def store_setting(name, value, data_type)
    connection.execute <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES (#{connection.quote(name)}, #{data_type}, #{connection.quote(value)}, NOW(), NOW())
    SQL
  end

  def setting_value(name)
    DB.query_single(
      "SELECT value FROM site_settings WHERE name = :name",
      name: name,
    ).first
  end

  it "renames image description settings to image caption settings", :aggregate_failures do
    store_setting("ai_helper_image_caption_agent", "-26", SiteSetting.types[:enum])
    store_setting("ai_post_image_descriptions_enabled", "t", SiteSetting.types[:bool])
    store_setting("ai_post_image_descriptions_per_post_limit", "12", SiteSetting.types[:integer])
    store_setting("ai_post_image_descriptions_backfill_hourly_rate", "4", SiteSetting.types[:integer])
    store_setting("ai_post_image_descriptions_backfill_max_age_days", "90", SiteSetting.types[:integer])

    migration.up

    expect(setting_value("ai_image_caption_agent")).to eq("-26")
    expect(setting_value("ai_post_image_captions_enabled")).to eq("t")
    expect(setting_value("ai_post_image_captions_per_post_limit")).to eq("12")
    expect(setting_value("ai_post_image_captions_backfill_hourly_rate")).to eq("4")
    expect(setting_value("ai_post_image_captions_backfill_max_age_days")).to eq("90")

    expect(setting_value("ai_helper_image_caption_agent")).to be_nil
    expect(setting_value("ai_post_image_descriptions_enabled")).to be_nil
    expect(setting_value("ai_post_image_descriptions_per_post_limit")).to be_nil
    expect(setting_value("ai_post_image_descriptions_backfill_hourly_rate")).to be_nil
    expect(setting_value("ai_post_image_descriptions_backfill_max_age_days")).to be_nil
  end

  it "rolls image caption settings back to their previous names", :aggregate_failures do
    store_setting("ai_image_caption_agent", "-26", SiteSetting.types[:enum])
    store_setting("ai_post_image_captions_enabled", "t", SiteSetting.types[:bool])
    store_setting("ai_post_image_captions_per_post_limit", "12", SiteSetting.types[:integer])
    store_setting("ai_post_image_captions_backfill_hourly_rate", "4", SiteSetting.types[:integer])
    store_setting("ai_post_image_captions_backfill_max_age_days", "90", SiteSetting.types[:integer])

    migration.down

    expect(setting_value("ai_helper_image_caption_agent")).to eq("-26")
    expect(setting_value("ai_post_image_descriptions_enabled")).to eq("t")
    expect(setting_value("ai_post_image_descriptions_per_post_limit")).to eq("12")
    expect(setting_value("ai_post_image_descriptions_backfill_hourly_rate")).to eq("4")
    expect(setting_value("ai_post_image_descriptions_backfill_max_age_days")).to eq("90")

    expect(setting_value("ai_image_caption_agent")).to be_nil
    expect(setting_value("ai_post_image_captions_enabled")).to be_nil
    expect(setting_value("ai_post_image_captions_per_post_limit")).to be_nil
    expect(setting_value("ai_post_image_captions_backfill_hourly_rate")).to be_nil
    expect(setting_value("ai_post_image_captions_backfill_max_age_days")).to be_nil
  end
end
