class CreateTopicEmbeds < ActiveRecord::Migration[4.2]
  def change
    create_table :topic_embeds, force: true do |t|
      t.integer :topic_id, null: false
      t.integer :post_id, null: false
      t.string :embed_url, null: false
      t.string :content_sha1, null: false, limit: 40
      t.timestamps null: false
    end

    add_index :topic_embeds, :embed_url, unique: true
  end
end
