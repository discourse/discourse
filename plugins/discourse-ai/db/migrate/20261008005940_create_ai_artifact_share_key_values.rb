# frozen_string_literal: true

class CreateAiArtifactShareKeyValues < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_artifact_share_key_values do |table|
      table.bigint :ai_artifact_share_id, null: false
      table.integer :user_id, null: false
      table.string :key, null: false, limit: 50
      table.string :value, null: false, limit: 20_000
      table.boolean :public, null: false, default: false
      table.timestamps
    end

    add_index :ai_artifact_share_key_values, :user_id
    add_index :ai_artifact_share_key_values,
              %i[ai_artifact_share_id user_id key],
              unique: true,
              name: "index_ai_artifact_share_kv_unique"
  end
end
