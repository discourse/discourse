# frozen_string_literal: true
class CreateAiArtifactsKeyValues < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_artifact_key_values do |t|
      t.bigint :ai_artifact_id, null: false
      t.integer :user_id, null: false
      t.string :key, null: false, limit: 50
      t.string :value, null: false, limit: 20_000
      t.boolean :public, null: false, default: false
      t.timestamps
    end

    add_index :ai_artifact_key_values,
              %i[ai_artifact_id user_id key],
              unique: true,
              name: "index_ai_artifact_kv_unique"
  end
end
