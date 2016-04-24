class CreateQueuedPreviewPostMaps < ActiveRecord::Migration
  def change
    create_table :queued_preview_post_maps do |t|
      t.integer :post_id
      t.integer :topic_id
      t.integer :queued_id

      t.timestamps null: false
    end
  end
end
