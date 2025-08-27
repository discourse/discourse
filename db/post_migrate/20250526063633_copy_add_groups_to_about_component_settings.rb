# frozen_string_literal: true

class CopyAddGroupsToAboutComponentSettings < ActiveRecord::Migration[7.2]
  MAPPING = {
    "about_groups" => "about_page_extra_groups",
    "order_additional_groups" => "about_page_extra_groups_order",
    "show_group_description" => "about_page_extra_groups_show_description",
    "show_initial_members" => "about_page_extra_groups_initial_members",
  }

  DATA_TYPE_MAPPING = {
    "about_groups" => 20,
    "order_additional_groups" => 7,
    "show_group_description" => 5,
    "show_initial_members" => 3,
  }

  def up
    theme_settings = execute(<<~SQL).to_a
      SELECT DISTINCT ON (name) name, value, updated_at
      FROM theme_settings
      WHERE theme_id IN (
        SELECT id
        FROM themes
        WHERE name = 'Add Groups to About'
        AND enabled = true
      )
      ORDER BY name, updated_at DESC;
    SQL

    return if theme_settings.blank?

    inserts = []

    theme_settings.each do |theme_setting|
      site_setting = MAPPING[theme_setting["name"]]

      next if !site_setting

      inserts << "('#{MAPPING[theme_setting["name"]]}', #{DATA_TYPE_MAPPING[theme_setting["name"]]}, '#{theme_setting["value"]}', NOW(), NOW())"
    end

    inserts << "('show_add_additional_about_groups', 5, 't', NOW(), NOW())"

    DB.exec(<<~SQL)
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES
      #{inserts.join(", ")}
      ON CONFLICT(name) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
