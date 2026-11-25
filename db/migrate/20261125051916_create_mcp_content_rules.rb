# frozen_string_literal: true

class CreateMcpContentRules < ActiveRecord::Migration[8.1]
  def change
    create_table :mcp_content_rules do |t|
      t.string :rule_kind, null: false
      t.jsonb :config, null: false, default: {}
      t.integer :updated_by_id
      t.timestamps
    end

    add_index :mcp_content_rules, :rule_kind, unique: true
  end
end
