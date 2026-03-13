# frozen_string_literal: true

class CreateAiToolActions < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_tool_actions do |t|
      t.string :tool_name, null: false
      t.jsonb :tool_parameters, default: {}, null: false
      t.references :ai_agent, null: false, foreign_key: true
      t.integer :bot_user_id, null: false
      t.integer :post_id
      t.timestamps
    end
  end
end
