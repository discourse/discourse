# frozen_string_literal: true

## If the *new* seeded General category was deleted before
# commit efb116d2bd4d1e02df9ddf79316112e0555b4c1e the site will need this migration
# to reset the general_category_id setting.

class FixGeneralCategoryId < ActiveRecord::Migration[7.0]
  def up
    general_category_id =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'general_category_id'")
    return if general_category_id.blank? || general_category_id[0].to_i < 0
    matching_category_id =
      DB.query_single("SELECT id FROM categories WHERE id = #{general_category_id[0]}")

    # If the general_category_id has been set to something other than the default and there isn't a matching
    # category to go with it we should set it back to the default.
    if general_category_id[0].to_i > 0 && matching_category_id.blank?
      execute "UPDATE site_settings SET value = '-1', updated_at = now() WHERE name = 'general_category_id';"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
