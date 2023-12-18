# frozen_string_literal: true

class SiteSettingRenameMigrationGenerator < Rails::Generators::Base
  argument :old_name, type: :string, banner: "old setting name", required: true
  argument :new_name, type: :string, banner: "new setting name", required: true

  def create_migration_file
    migration_version = ActiveRecord::Migration.next_migration_number(0)
    file_path = "db/migrate/#{migration_version}_rename_#{old_name}_setting.rb"
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
    if !SiteSetting.respond_to?(name)
      say "Site setting with #{name} does not exist"
      raise ArgumentError
    end
  end
end
