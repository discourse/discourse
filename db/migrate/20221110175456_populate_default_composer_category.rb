# frozen_string_literal: true

## If the general_category_id has a value, set the *new*
# default_composer_category site setting to match

class PopulateDefaultComposerCategory < ActiveRecord::Migration[7.0]
  def up
    general_category_id =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'general_category_id'")
    return if general_category_id.blank? || general_category_id[0].to_i < 0
    default_composer_category =
      DB.query_single("SELECT value FROM site_settings where name = 'default_composer_category'")
    return if !default_composer_category.blank?
    DB.exec(
      "INSERT INTO site_settings(name, value, data_type, created_at, updated_at)
      VALUES('default_composer_category', :setting, '16', NOW(), NOW())",
      setting: general_category_id[0].to_i,
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
