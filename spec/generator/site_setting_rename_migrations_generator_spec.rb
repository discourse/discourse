# frozen_string_literal: true

require "rails/generators"
require "generators/site_setting_rename_migration/site_setting_rename_migration_generator"

RSpec.describe SiteSettingRenameMigrationGenerator, type: :generator do
  it "generates the correct migration" do
    freeze_time DateTime.parse("2010-01-01 12:00")

    silence_stdout do
      described_class.start(
        %w[site_description contact_email],
        destination_root: "#{Rails.root}/tmp",
      )
    end

    file_path = "#{Rails.root}/tmp/db/migrate/20100101120000_rename_site_description_setting.rb"
    expected_content = <<~EXPECTED_CONTENT
      # frozen_string_literal: true

      class RenameSiteDescriptionSetting < ActiveRecord::Migration[7.0]
        def up
          execute "UPDATE site_settings SET name = 'contact_email' WHERE name = 'site_description'"
        end

        def down
          execute "UPDATE site_settings SET name = 'site_description' WHERE name = 'contact_email'"
        end
      end
    EXPECTED_CONTENT

    expect(File.read(file_path)).to eq(expected_content)
    File.delete(file_path)
  end

  it "raises an error when old name is incorrect" do
    silence_stdout do
      expect { described_class.start(%w[wrong_name contact_email]) }.to raise_error(ArgumentError)
    end
  end

  it "raises an error when new name is incorrect" do
    silence_stdout do
      expect { described_class.start(%w[site_description wrong_name]) }.to raise_error(
        ArgumentError,
      )
    end
  end
end
