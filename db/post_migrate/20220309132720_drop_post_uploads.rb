# frozen_string_literal: true

class DropPostUploads < ActiveRecord::Migration[6.1]
  def up
    drop_table :post_uploads
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
