# frozen_string_literal: true

class CreateUploadReferences < ActiveRecord::Migration[6.1]
  def change
    create_table :upload_references do |t|
      t.references :upload, null: false
      t.references :target, polymorphic: true, null: false
      t.timestamps
    end

    add_index :upload_references,
              %i[upload_id target_type target_id],
              unique: true,
              name: "index_upload_references_on_upload_and_target"
  end
end
