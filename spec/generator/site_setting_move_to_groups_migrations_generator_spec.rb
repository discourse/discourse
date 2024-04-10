# frozen_string_literal: true

require "rails/generators"
require "generators/site_setting_move_to_groups_migration/site_setting_move_to_groups_migration_generator"

RSpec.describe SiteSettingMoveToGroupsMigrationGenerator, type: :generator do
  it "generates the correct migration for TrustLevelSetting" do
    freeze_time DateTime.parse("2010-01-01 12:00")

    silence_stdout do
      described_class.start(
        %w[min_trust_level_to_allow_invite allow_invite_groups],
        destination_root: "#{Rails.root}/tmp",
      )
    end

    file_path =
      "#{Rails.root}/tmp/db/migrate/20100101120000_fill_allow_invite_groups_based_on_deprecated_setting.rb"
    expected_content = <<~EXPECTED_CONTENT
      # frozen_string_literal: true

      class FillAllowInviteGroupBasedOnDeprecatedSetting < ActiveRecord::Migration[7.0]
        def up
          old_setting_trust_level =
            DB.query_single(
              "SELECT value FROM site_settings WHERE name = 'min_trust_level_to_allow_invite' LIMIT 1",
            ).first

          if old_setting_trust_level.present?
            allowed_groups = "1\#\{old_setting_trust_level\}"

            DB.exec(
              "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
              VALUES('allow_invite_groups', :setting, '20', NOW(), NOW())",
              setting: allowed_groups,
            )
          end
        end

        def down
          raise ActiveRecord::IrreversibleMigration
        end
      end
    EXPECTED_CONTENT

    expect(File.read(file_path)).to eq(expected_content)
  ensure
    File.delete(file_path)
  end

  it "generates the correct migration for TrustLevelAndStaffSetting" do
    freeze_time DateTime.parse("2010-01-01 12:00")

    silence_stdout do
      described_class.start(
        %w[min_trust_level_to_allow_invite_tl_and_staff allow_invite_groups],
        destination_root: "#{Rails.root}/tmp",
      )
    end

    file_path =
      "#{Rails.root}/tmp/db/migrate/20100101120000_fill_allow_invite_groups_based_on_deprecated_setting.rb"
    expected_content = <<~EXPECTED_CONTENT
      # frozen_string_literal: true

      class FillAllowInviteGroupBasedOnDeprecatedSetting < ActiveRecord::Migration[7.0]
        def up
          old_setting_trust_level =
            DB.query_single(
              "SELECT value FROM site_settings WHERE name = 'min_trust_level_to_allow_invite_tl_and_staff' LIMIT 1",
            ).first

          if old_setting_trust_level.present?
            allowed_groups =
              case old_setting_trust_level
              when "admin"
                "1"
              when "staff"
                "3"
              when "0"
                "10"
              when "1"
                "11"
              when "2"
                "12"
              when "3"
                "13"
              when "4"
                "14"
              end

            DB.exec(
              "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
              VALUES('allow_invite_groups', :setting, '20', NOW(), NOW())",
              setting: allowed_groups,
            )
          end
        end

        def down
          raise ActiveRecord::IrreversibleMigration
        end
      end
    EXPECTED_CONTENT

    expect(File.read(file_path)).to eq(expected_content)
  ensure
    File.delete(file_path)
  end

  it "raises an error when old name is incorrect" do
    silence_stdout do
      expect { described_class.start(%w[wrong_name allow_invite_groups]) }.to raise_error(
        ArgumentError,
      )
    end
  end

  it "raises an error when new name is incorrect" do
    silence_stdout do
      expect {
        described_class.start(%w[min_trust_level_to_allow_invite wrong_name])
      }.to raise_error(ArgumentError)
    end
  end

  it "raises an error when old setting is incorrect type" do
    silence_stdout do
      expect { described_class.start(%w[title allow_invite_groups]) }.to raise_error(ArgumentError)
    end
  end
end
