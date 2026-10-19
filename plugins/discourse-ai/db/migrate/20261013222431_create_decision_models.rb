# frozen_string_literal: true
class CreateDecisionModels < ActiveRecord::Migration[8.1]
  def change
    create_table :decision_models do |t|
      t.string :display_name, null: false, limit: 100
      t.string :name, null: false, limit: 255
      t.string :provider, null: false, limit: 50
      t.string :url, null: false, limit: 1000
      t.bigint :ai_secret_id
      t.boolean :vision_enabled, null: false, default: false
      t.timestamps
    end

    add_index :decision_models, :ai_secret_id
  end
end
