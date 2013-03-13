class CreateIncomingLinks < ActiveRecord::Migration
  def change
    create_table :incoming_links do |t|
      t.integer :site_id, null: false
      t.string :url, limit: 1000, null: false
      t.string :referer, limit: 1000, null: false
      t.string :domain, limit: 100, null: false
      t.integer :forum_thread_id, null: true
      t.integer :post_number, null: true
      t.timestamps
    end

    add_index :incoming_links, [:site_id, :forum_thread_id, :post_number], name: 'incoming_index'
  end
end
