class AddForumThreadStates < ActiveRecord::Migration
  def change
    add_column :forum_threads, :closed, :boolean, default: false, null: false
    add_column :forum_threads, :sticky, :boolean, default: false, null: false
    add_column :forum_threads, :archived, :boolean, default: false, null: false
  end
end
