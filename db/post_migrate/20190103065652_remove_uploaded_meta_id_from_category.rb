# frozen_string_literal: true

require 'migration/column_dropper'

class RemoveUploadedMetaIdFromCategory < ActiveRecord::Migration[5.2]
  DROPPED_COLUMNS ||= {
    categories: %i{uploaded_meta_id}
  }

  def up
    DROPPED_COLUMNS.each do |table, columns|
      Migration::ColumnDropper.execute_drop(table, columns)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
