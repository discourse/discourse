# frozen_string_literal: true

class CreateExternalUploadStubs < ActiveRecord::Migration[6.1]
  def change
    create_table :external_upload_stubs do |t|
      t.string :key, null: false
      t.string :original_filename, null: false
      t.integer :status, default: 1, null: false, index: true
      t.string :unique_identifier, null: false, index: true
      t.integer :created_by_id, null: false, index: true
      t.string :upload_type, null: false

      t.timestamps
    end
  end
end
