# frozen_string_literal: true
class AddAiArtifacts < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_artifacts do |t|
      t.integer :user_id, null: false
      t.integer :post_id, null: false
      t.string :name, null: false, limit: 255
      t.string :html, limit: 65_535 # ~64KB limit
      t.string :css, limit: 65_535 # ~64KB limit
      t.string :js, limit: 65_535 # ~64KB limit
      t.jsonb :metadata # For any additional properties

      t.timestamps
    end
  end
end
