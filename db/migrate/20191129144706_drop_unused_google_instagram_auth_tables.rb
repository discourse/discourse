# frozen_string_literal: true

require "migration/table_dropper"

class DropUnusedGoogleInstagramAuthTables < ActiveRecord::Migration[6.0]
  DROPPED_TABLES = %i[google_user_infos instagram_user_infos]

  def up
    DROPPED_TABLES.each { |table| Migration::TableDropper.execute_drop(table) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
