# frozen_string_literal: true

class MigrateSharedEdits < ActiveRecord::Migration[6.0]
  def up
    create_table :shared_edit_revisions do |t|
      t.integer :post_id, null: false
      t.string :raw
      t.string :revision, null: false
      t.integer :user_id, null: false
      t.string :client_id, null: false
      t.integer :version, null: false
      t.integer :post_revision_id
      t.timestamps
    end

    add_index :shared_edit_revisions, %i[post_id version], unique: true
  end

  def down
    drop_table :shared_edit_revisions
  end
end
