# frozen_string_literal: true

require "migration/table_dropper"

class RemoveSuperfluousTables < ActiveRecord::Migration[5.2]
  DROPPED_TABLES = %i[category_featured_users versions topic_status_updates]

  def up
    DROPPED_TABLES.each { |table| Migration::TableDropper.execute_drop(table) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
