# frozen_string_literal: true

class SiteSettingRenameMigrationGenerator < Rails::Generators::Base
  argument :old_name, type: :string, banner: "old setting name", required: true
  argument :new_name, type: :string, banner: "new setting name", required: true

  def create_migration_file
    timestamp = Time.zone.now.to_s.tr("^0-9", "")[0..13]
    file_path = "db/migrate/#{timestamp}_rename_#{old_name}_setting.rb"
    class_name = "Rename#{old_name.classify}Setting"

    validate_setting_name!(old_name)
    validate_setting_name!(new_name)

    create_file file_path, <<~MIGRATION_FILE
      # frozen_string_literal: true

      class #{class_name} < ActiveRecord::Migration[7.0]
        def up
          execute "UPDATE site_settings SET name = '#{new_name}' WHERE name = '#{old_name}'"
        end

        def down
          execute "UPDATE site_settings SET name = '#{old_name}' WHERE name = '#{new_name}'"
        end
      end
    MIGRATION_FILE
  end

  private

  def validate_setting_name!(name)
    begin
      SiteSetting.send(name)
    rescue NoMethodError
      say "Site setting with #{name} does not exist"
      raise ArgumentError
    end
  end
end
