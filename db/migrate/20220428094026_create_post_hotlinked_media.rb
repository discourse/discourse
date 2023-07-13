# frozen_string_literal: true

class CreatePostHotlinkedMedia < ActiveRecord::Migration[6.1]
  def change
    reversible do |dir|
      dir.up { execute <<~SQL }
          CREATE TYPE hotlinked_media_status AS ENUM('downloaded', 'too_large', 'download_failed', 'upload_create_failed')
        SQL
      dir.down { execute <<~SQL }
          DROP TYPE hotlinked_media_status
        SQL
    end

    create_table :post_hotlinked_media do |t|
      t.bigint :post_id, null: false
      t.string :url, null: false
      t.column :status, :hotlinked_media_status, null: false
      t.bigint :upload_id
      t.timestamps

      # Failed on some installations due to index size. Repaired in 20220428094027
      # t.index [:post_id, :url], unique: true
    end

    execute <<~SQL
      CREATE UNIQUE INDEX index_post_hotlinked_media_on_post_id_and_url_md5
      ON post_hotlinked_media (post_id, md5(url));
    SQL

    reversible do |dir|
      dir.up do
        execute <<~SQL
          INSERT INTO post_hotlinked_media (post_id, url, status, upload_id, created_at, updated_at)
          SELECT
            post_id,
            obj.key AS url,
            'downloaded',
            obj.value::bigint AS upload_id,
            pcf.created_at,
            pcf.updated_at
          FROM post_custom_fields pcf
          JOIN json_each_text(pcf.value::json) obj ON true
          JOIN uploads ON obj.value::bigint = uploads.id
          WHERE name='downloaded_images'
          AND pcf.value LIKE '{%' -- JSON Object
          ON CONFLICT (post_id, md5(url::text)) DO NOTHING
        SQL

        execute <<~SQL
          INSERT INTO post_hotlinked_media (post_id, url, status, upload_id, created_at, updated_at)
          SELECT
            post_id,
            url.value,
            'download_failed',
            NULL,
            pcf.created_at,
            pcf.updated_at
          FROM post_custom_fields pcf
          JOIN json_array_elements_text(pcf.value::json) url ON true
          WHERE name='broken_images'
          AND pcf.value LIKE '[%' -- JSON Array
          ON CONFLICT (post_id, md5(url::text)) DO NOTHING
        SQL

        execute <<~SQL
          INSERT INTO post_hotlinked_media (post_id, url, status, upload_id, created_at, updated_at)
          SELECT
            post_id,
            url.value,
            'too_large',
            NULL,
            pcf.created_at,
            pcf.updated_at
          FROM post_custom_fields pcf
          JOIN json_array_elements_text(pcf.value::json) url ON true
          WHERE name='large_images'
          AND pcf.value LIKE '[%' -- JSON Array
          ON CONFLICT (post_id, md5(url::text)) DO NOTHING
        SQL
      end
    end
  end
end
