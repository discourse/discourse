# frozen_string_literal: true

class SiteSettingMoveToGroupsMigrationGenerator < Rails::Generators::Base
  include SiteSettingExtension

  argument :old_name, type: :string, banner: "old setting name", required: true
  argument :new_name, type: :string, banner: "new setting name", required: true

  def create_migration_file
    migration_version = ActiveRecord::Migration.next_migration_number(0)
    file_path = "db/migrate/#{migration_version}_fill_#{new_name}_based_on_deprecated_setting.rb"
    class_name = "Fill#{new_name.classify}BasedOnDeprecatedSetting"

    load_all_settings
    validate_setting_name!(old_name)
    validate_setting_name!(new_name)
    validate_setting_type!(old_name)

    create_file file_path, <<~MIGRATION_FILE if setting_type(old_name) == "TrustLevelSetting"
        # frozen_string_literal: true

        class #{class_name} < ActiveRecord::Migration[7.0]
          def up
            old_setting_trust_level =
              DB.query_single(
                "SELECT value FROM site_settings WHERE name = '#{old_name}' LIMIT 1",
              ).first

            if old_setting_trust_level.present?
              allowed_groups = "1\#\{old_setting_trust_level\}"

              DB.exec(
                "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
                VALUES('#{new_name}', :setting, '20', NOW(), NOW())",
                setting: allowed_groups,
              )
            end
          end

          def down
            raise ActiveRecord::IrreversibleMigration
          end
        end
      MIGRATION_FILE
    if setting_type(old_name) == "TrustLevelAndStaffSetting"
      create_file file_path, <<~MIGRATION_FILE
        # frozen_string_literal: true

        class #{class_name} < ActiveRecord::Migration[7.0]
          def up
            old_setting_trust_level =
              DB.query_single(
                "SELECT value FROM site_settings WHERE name = '#{old_name}' LIMIT 1",
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
                VALUES('#{new_name}', :setting, '20', NOW(), NOW())",
                setting: allowed_groups,
              )
            end
          end

          def down
            raise ActiveRecord::IrreversibleMigration
          end
        end
      MIGRATION_FILE
    end
  end

  private

  def load_all_settings
    load_settings(File.join(Rails.root, "config", "site_settings.yml"))

    if GlobalSetting.load_plugins?
      Dir[File.join(Rails.root, "plugins", "*", "config", "settings.yml")].each do |file|
        load_settings(file, plugin: file.split("/")[-3])
      end
    end

    if Rails.env.test?
      load_settings(
        File.join(Rails.root, "spec", "fixtures", "site_settings", "generator_test.yml"),
      )
    end
  end

  def validate_setting_name!(name)
    if !self.respond_to?(name)
      say "Site setting with #{name} does not exist"
      raise ArgumentError
    end
  end

  def setting_type(name)
    if type_supervisor.get_type(name.to_sym) == :enum
      return type_supervisor.get_enum_class(name.to_sym).to_s
    end

    nil
  end

  def validate_setting_type!(name)
    if !%w[TrustLevelSetting TrustLevelAndStaffSetting].include?(setting_type(name))
      say "Site setting with #{name} must be TrustLevelSetting"
      raise ArgumentError
    end
  end
end
