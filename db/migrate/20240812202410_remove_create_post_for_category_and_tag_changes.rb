# frozen_string_literal: true
class RemoveCreatePostForCategoryAndTagChanges < ActiveRecord::Migration[7.1]
  def up
    execute "DELETE FROM site_settings WHERE name = 'create_post_for_category_and_tag_changes'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
