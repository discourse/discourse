# frozen_string_literal: true

class CreateAiArtifactShares < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_artifact_shares do |table|
      table.bigint :ai_artifact_id, null: false
      table.integer :user_id, null: false
      table.string :share_key, null: false
      table.string :name, null: false
      table.integer :version_number, null: false, default: 0
      table.string :html, limit: 65_535
      table.string :css, limit: 65_535
      table.string :js, limit: 65_535
      table.timestamps
    end

    add_index :ai_artifact_shares, :share_key, unique: true
    add_index :ai_artifact_shares, %i[user_id created_at]
    add_index :ai_artifact_shares, %i[user_id ai_artifact_id], unique: true
    add_index :ai_artifact_shares, :ai_artifact_id
  end
end
