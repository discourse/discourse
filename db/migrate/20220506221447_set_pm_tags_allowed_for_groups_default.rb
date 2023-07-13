# frozen_string_literal: true

class SetPmTagsAllowedForGroupsDefault < ActiveRecord::Migration[7.0]
  def up
    # if the old SiteSetting of `allow_staff_to_tag_pms` was set to true, update the new SiteSetting of
    # `pm_tags_allowed_for_groups` default to include the staff group
    allow_staff_to_tag_pms =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'allow_staff_to_tag_pms'").first

    # Dynamically sets the default value
    if allow_staff_to_tag_pms == "t"
      # Include all staff groups - admins/moderators/staff
      default = "1|2|3"
      execute "INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
                VALUES ('pm_tags_allowed_for_groups', 20, '#{default}', now(), now())"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
