# frozen_string_literal: true

class SetPmTagsAllowedForGroupsDefault < ActiveRecord::Migration[7.0]
  def up

    # if the old SiteSetting of `allow_staff_to_tag_pms` was set to true, update the new SiteSetting of
    # `pm_tags_allowed_for_groups` default to include the staff group
    allow_staff_to_tag_pms = DB.query_single("SELECT value FROM site_settings WHERE name = 'allow_staff_to_tag_pms'").first

    # Dynamically sets the default value
    if allow_staff_to_tag_pms == "t"
      default = []
      Group::AUTO_GROUPS.select do |group_key, id|
        if Group::STAFF_GROUPS.include?(group_key)
          default << id
        end
      end
      default = default.join("|")
      execute "INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
                VALUES ('pm_tags_allowed_for_groups', #{SiteSettings::TypeSupervisor.types[:group_list]}, '#{default}', now(), now())"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
