# frozen_string_literal: true

class AddDominantColorToUploads < ActiveRecord::Migration[7.0]
  def change
    add_column :uploads, :dominant_color, :text, limit: 6, null: true
    add_index :uploads, :id, where: "dominant_color IS NULL"
  end
end
