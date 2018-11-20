class AddPinnedGloballyToTopics < ActiveRecord::Migration[4.2]
  def up
    add_column :topics, :pinned_globally, :boolean, null: false, default: false
    execute "UPDATE topics set pinned_globally = 't' where category_id = (
      SELECT value::int FROM site_settings WHERE name = 'uncategorized_category_id') AND pinned_at IS NOT NULL
    "
  end

  def down
    remove_column :topics, :pinned_globally
  end
end
