# frozen_string_literal: true

class AddSecretContractsToAiTools < ActiveRecord::Migration[7.0]
  def change
    add_column :ai_tools, :secret_contracts, :jsonb, default: [], null: false

    create_table :ai_tool_secret_bindings do |t|
      t.bigint :ai_tool_id, null: false
      t.string :alias, null: false, limit: 100
      t.bigint :ai_secret_id, null: false
      t.integer :created_by_id
      t.timestamps
    end

    add_index :ai_tool_secret_bindings, :ai_tool_id
    add_index :ai_tool_secret_bindings, :ai_secret_id
    add_index :ai_tool_secret_bindings, %i[ai_tool_id alias], unique: true
  end
end
