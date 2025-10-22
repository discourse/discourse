# frozen_string_literal: true

class SetAssignAllowedOnGroupsDefault < ActiveRecord::Migration[5.2]
  def up
    current_values =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'assign_allowed_on_groups'",
      ).first

    # Dynamically sets the default value, supports older versions.
    if current_values.nil?
      min_version = 201_907_171_337_43
      migrated_site_setting =
        DB.query_single(
          "SELECT schema_migrations.version FROM schema_migrations WHERE schema_migrations.version = '#{min_version}'",
        ).first
      default = migrated_site_setting.present? ? Group::AUTO_GROUPS[:staff] : "staff"

      execute "INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
                VALUES ('assign_allowed_on_groups', #{SiteSettings::TypeSupervisor.types[:group_list]}, '#{default}', now(), now())"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
