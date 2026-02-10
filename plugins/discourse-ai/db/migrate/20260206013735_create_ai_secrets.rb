# frozen_string_literal: true

class CreateAiSecrets < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_secrets do |t|
      t.string :name, limit: 100, null: false
      t.string :secret, limit: 10_000, null: false
      t.integer :created_by_id
      t.timestamps
    end

    add_index :ai_secrets, :name, unique: true
  end
end
