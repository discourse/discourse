class AddReflectionToForumThreadLinks < ActiveRecord::Migration[4.2]
  def change
    add_column :forum_thread_links, :reflection, :boolean, default: false
    change_column :forum_thread_links, :post_id, :integer, null: true
  end
end
