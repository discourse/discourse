# frozen_string_literal: true

class CreateBackupMetadata < ActiveRecord::Migration[5.2]
  def change
    create_table :backup_metadata do |t|
      t.string :name, null: false
      t.string :value
    end
  end
end
