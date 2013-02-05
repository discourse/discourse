class AddIncomingLinkCountToForumThreads < ActiveRecord::Migration
  def change
    add_column :forum_threads, :incoming_link_count, :integer, default: 0, null: false
  end
end
