# frozen_string_literal: true
class CreateEmbeddingDefinitions < ActiveRecord::Migration[7.2]
  def change
    create_table :embedding_definitions do |t|
      t.string :display_name, null: false
      t.integer :dimensions, null: false
      t.integer :max_sequence_length, null: false
      t.integer :version, null: false, default: 1
      t.string :pg_function, null: false
      t.string :provider, null: false
      t.string :tokenizer_class, null: false
      t.string :url, null: false
      t.string :api_key
      t.boolean :seeded, null: false, default: false
      t.jsonb :provider_params
      t.timestamps
    end
  end
end
