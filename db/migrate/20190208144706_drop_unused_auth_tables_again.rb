# frozen_string_literal: true

require "migration/table_dropper"

class DropUnusedAuthTablesAgain < ActiveRecord::Migration[5.2]
  DROPPED_TABLES = %i[facebook_user_infos twitter_user_infos].freeze

  def up
    DROPPED_TABLES.each { |table| Migration::TableDropper.execute_drop(table) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
