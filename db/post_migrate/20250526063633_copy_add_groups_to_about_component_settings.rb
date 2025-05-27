# frozen_string_literal: true

class CopyAddGroupsToAboutComponentSettings < ActiveRecord::Migration[7.2]
  MAPPING = {
    "about_groups" => "about_page_extra_groups",
    "order_additional_groups" => "about_page_extra_groups_order",
    "show_group_description" => "about_page_extra_groups_show_description",
    "show_initial_members" => "about_page_extra_groups_initial_members",
  }

  def up
    theme_settings = execute(<<~SQL).to_a
      SELECT name, value
      FROM theme_settings
      WHERE theme_id = (
        SELECT id
        FROM themes
        WHERE name = 'Add Groups to About'
        AND enabled = true
      )
    SQL

    return if theme_settings.blank?

    theme_settings.each do |theme_setting|
      site_setting = MAPPING[theme_setting["name"]]

      next if !site_setting

      SiteSetting.set(MAPPING[theme_setting["name"]], theme_setting["value"])
    end

    SiteSetting.set("show_additional_about_groups", true)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
