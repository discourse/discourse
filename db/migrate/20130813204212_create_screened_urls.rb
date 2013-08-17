class CreateScreenedUrls < ActiveRecord::Migration
  def change
    create_table :screened_urls do |t|
      t.string :url, null: false
      t.string :domain, null: false
      t.integer :action_type, null: false
      t.integer :match_count, null: false, default: 0
      t.datetime :last_match_at
      t.timestamps
    end
    add_index :screened_urls, :url, unique: true
    add_index :screened_urls, :last_match_at
  end
end
