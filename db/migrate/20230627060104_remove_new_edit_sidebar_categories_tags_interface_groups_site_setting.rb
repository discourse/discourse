# frozen_string_literal: true

class RemoveNewEditSidebarCategoriesTagsInterfaceGroupsSiteSetting < ActiveRecord::Migration[7.0]
  def up
    execute(
      "DELETE FROM site_settings WHERE name = 'new_edit_sidebar_categories_tags_interface_groups'",
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
