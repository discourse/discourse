# frozen_string_literal: true

class AddShaToUploads < ActiveRecord::Migration[4.2]
  def change
    add_column :uploads, :sha, :string, null: true
    add_index :uploads, :sha, unique: true
  end
end
