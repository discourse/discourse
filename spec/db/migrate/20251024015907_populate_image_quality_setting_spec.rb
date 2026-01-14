# frozen_string_literal: true

require Rails.root.join("db/migrate/20251024015907_populate_image_quality_setting.rb")

RSpec.describe PopulateImageQualitySetting do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "works" do
    mapping = { 60 => 50, 75 => 70, 99 => 90, 100 => 100 }

    mapping.each do |current, expected|
      # SETUP
      DB.exec(<<~SQL)
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        VALUES ('recompress_original_jpg_quality', 1, #{current}, NOW(), NOW())
        ON CONFLICT (name) DO UPDATE SET value = EXCLUDED.value
      SQL

      # EXERCISE
      PopulateImageQualitySetting.new.up

      # ASSERT
      row = DB.query("SELECT value FROM site_settings WHERE name = 'image_quality'")[0]

      expect(row.value.to_i).to eq(expected)
    end
  end
end
