# frozen_string_literal: true

class SetPmTagsAllowedForGroupsDefault < ActiveRecord::Migration[7.0]
  def up

    # if the old SiteSetting of `allow_staff_to_tag_pms` was set to true, update the new SiteSetting of
    # `pm_tags_allowed_for_groups` default to include the staff group
    allow_staff_to_tag_pms = DB.query_single("SELECT value FROM site_settings WHERE name = 'allow_staff_to_tag_pms'").first
    current_values = DB.query_single("SELECT value FROM site_settings WHERE name = 'pm_tags_allowed_for_groups'").first

    # Dynamically sets the default value, supports older versions.
    if allow_staff_to_tag_pms == "t" && current_values.nil?
      min_version = 201_907_171_337_43
      migrated_site_setting = DB.query_single(
        "SELECT schema_migrations.version FROM schema_migrations WHERE schema_migrations.version = '#{min_version}'"
      ).first
      default = migrated_site_setting.present? ? Group::AUTO_GROUPS[:staff] : 'staff'

      execute "INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
                VALUES ('pm_tags_allowed_for_groups', #{SiteSettings::TypeSupervisor.types[:group_list]}, '#{default}', now(), now())"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
