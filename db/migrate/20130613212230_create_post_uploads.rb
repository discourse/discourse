class CreatePostUploads < ActiveRecord::Migration
  def up
    create_table :post_uploads do |t|
      t.integer :post_id, null: false
      t.integer :upload_id, null: false
    end

    # no support for this till rails 4
    execute 'create unique index idx_unique_post_uploads on post_uploads(post_id, upload_id)'
  end

  def down
    drop_table :post_uploads
  end
end
