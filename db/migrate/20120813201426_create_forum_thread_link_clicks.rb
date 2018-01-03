class CreateForumThreadLinkClicks < ActiveRecord::Migration[4.2]
  def change
    create_table :forum_thread_link_clicks do |t|
      t.references :forum_thread_link, null: false
      t.references :user, null: true
      t.integer :ip, null: false, limit: 8
      t.timestamps null: false
    end

    add_column :forum_thread_links, :clicks, :integer, default: 0, null: false
    add_index :forum_thread_link_clicks, :forum_thread_link_id, name: :by_link
  end
end
