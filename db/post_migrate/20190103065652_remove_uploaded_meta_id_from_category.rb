require 'migration/column_dropper'

class RemoveUploadedMetaIdFromCategory < ActiveRecord::Migration[5.2]
  def up
    Migration::ColumnDropper.execute_drop(:categories, %i{uploaded_meta_id})
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
