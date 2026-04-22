# frozen_string_literal: true

require "migration/table_dropper"

class MoveWebArtifactsToCore < ActiveRecord::Migration[8.0]
  def up
    create_table :web_artifacts, if_not_exists: true do |t|
      t.integer :user_id, null: false
      t.integer :post_id
      t.string :name, null: false, limit: 255
      t.string :html, limit: 65_535
      t.string :css, limit: 65_535
      t.string :js, limit: 65_535
      t.jsonb :metadata
      t.timestamps
    end

    create_table :web_artifact_versions, if_not_exists: true do |t|
      t.bigint :web_artifact_id, null: false
      t.integer :version_number, null: false
      t.string :html, limit: 65_535
      t.string :css, limit: 65_535
      t.string :js, limit: 65_535
      t.jsonb :metadata
      t.string :change_description
      t.timestamps
    end

    unless index_exists?(:web_artifact_versions, %i[web_artifact_id version_number])
      add_index :web_artifact_versions,
                %i[web_artifact_id version_number],
                unique: true,
                name: "index_web_artifact_versions_unique"
    end

    create_table :web_artifact_key_values, if_not_exists: true do |t|
      t.bigint :web_artifact_id, null: false
      t.integer :user_id, null: false
      t.string :key, null: false, limit: 50
      t.string :value, null: false, limit: 20_000
      t.boolean :public, null: false, default: false
      t.timestamps
    end

    unless index_exists?(:web_artifact_key_values, %i[web_artifact_id user_id key])
      add_index :web_artifact_key_values,
                %i[web_artifact_id user_id key],
                unique: true,
                name: "index_web_artifact_kv_unique"
    end

    if table_exists?(:ai_artifacts)
      execute <<~SQL
        INSERT INTO web_artifacts (id, user_id, post_id, name, html, css, js, metadata, created_at, updated_at)
        SELECT id, user_id, post_id, name, html, css, js, metadata, created_at, updated_at
        FROM ai_artifacts
        ON CONFLICT DO NOTHING
      SQL

      execute <<~SQL
        INSERT INTO web_artifact_versions (id, web_artifact_id, version_number, html, css, js, metadata, change_description, created_at, updated_at)
        SELECT id, ai_artifact_id, version_number, html, css, js, metadata, change_description, created_at, updated_at
        FROM ai_artifact_versions
        ON CONFLICT DO NOTHING
      SQL

      execute <<~SQL
        INSERT INTO web_artifact_key_values (id, web_artifact_id, user_id, key, value, public, created_at, updated_at)
        SELECT id, ai_artifact_id, user_id, key, value, public, created_at, updated_at
        FROM ai_artifact_key_values
        ON CONFLICT DO NOTHING
      SQL

      # Sync sequences so new IDs don't collide with copied data
      %w[web_artifacts web_artifact_versions web_artifact_key_values].each do |table|
        execute <<~SQL
          SELECT setval(pg_get_serial_sequence('#{table}', 'id'), COALESCE((SELECT MAX(id) FROM #{table}), 0) + 1, false)
        SQL
      end

      Migration::TableDropper.read_only_table("ai_artifacts")
      Migration::TableDropper.read_only_table("ai_artifact_versions")
      Migration::TableDropper.read_only_table("ai_artifact_key_values")
    end

    # Rename site settings from ai_artifact_* to web_artifact_*
    execute "UPDATE site_settings SET name = 'web_artifact_security' WHERE name = 'ai_artifact_security'"
    execute "UPDATE site_settings SET name = 'web_artifact_kv_value_max_length' WHERE name = 'ai_artifact_kv_value_max_length'"
    execute "UPDATE site_settings SET name = 'web_artifact_max_keys_per_user_per_artifact' WHERE name = 'ai_artifact_max_keys_per_user_per_artifact'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
