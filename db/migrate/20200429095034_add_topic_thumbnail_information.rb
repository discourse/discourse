# frozen_string_literal: true

class AddTopicThumbnailInformation < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    # tables are huge ... avoid holding on to large number of locks by doing one at a time
    execute <<~SQL
      ALTER TABLE posts
      ADD COLUMN IF NOT EXISTS image_upload_id bigint
    SQL

    execute <<~SQL
      ALTER TABLE topics
      ADD COLUMN IF NOT EXISTS image_upload_id bigint
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
      index_posts_on_image_upload_id ON posts USING btree (image_upload_id)
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
      index_topics_on_image_upload_id ON topics USING btree (image_upload_id)
    SQL

    ActiveRecord::Base.transaction do
      add_column :theme_modifier_sets, :topic_thumbnail_sizes, :string, array: true

      create_table :topic_thumbnails do |t|
        t.references :upload, null: false
        t.references :optimized_image, null: true
        t.integer :max_width, null: false
        t.integer :max_height, null: false
      end

      add_index :topic_thumbnails,
                %i[upload_id max_width max_height],
                name: :unique_topic_thumbnails,
                unique: true
    end
  end

  def down
    raise IrreversibleMigration
  end
end
