# frozen_string_literal: true

class DropUserUploads < ActiveRecord::Migration[6.1]
  def up
    drop_table :user_uploads
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
