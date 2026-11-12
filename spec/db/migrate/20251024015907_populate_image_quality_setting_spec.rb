# frozen_string_literal: true

require Rails.root.join("db/migrate/20251024015907_populate_image_quality_setting.rb")

RSpec.describe PopulateImageQualitySetting do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after do
    ActiveRecord::Migration.verbose = @original_verbose
    Discourse.clear_site_creation_date_cache
  end

  it "is a no-op on fresh installs" do
    DB.exec("UPDATE schema_migration_details SET created_at = NOW()")
    Discourse.clear_site_creation_date_cache

    expect { PopulateImageQualitySetting.new.up }.not_to change {
      DB.query_single("SELECT count(*) FROM site_settings WHERE name = 'image_quality'").first
    }
  end

  context "when the site is an existing install" do
    before do
      DB.exec("UPDATE schema_migration_details SET created_at = NOW() - INTERVAL '2 hours'")
      Discourse.clear_site_creation_date_cache
    end

    it "maps recompress_original_jpg_quality into image_quality buckets" do
      mapping = { 60 => 50, 75 => 70, 99 => 90, 100 => 100 }

      mapping.each do |current, expected|
        DB.exec(<<~SQL)
          INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
          VALUES ('recompress_original_jpg_quality', 1, #{current}, NOW(), NOW())
          ON CONFLICT (name) DO UPDATE SET value = EXCLUDED.value
        SQL

        PopulateImageQualitySetting.new.up

        row = DB.query("SELECT value FROM site_settings WHERE name = 'image_quality'")[0]
        expect(row.value.to_i).to eq(expected)
      end
    end
  end
end
