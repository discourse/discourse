# frozen_string_literal: true

class DropPostUploadsTable < ActiveRecord::Migration[7.0]
  DROPPED_TABLES = %i[post_uploads].freeze

  def up
    DROPPED_TABLES.each { |table| Migration::TableDropper.execute_drop(table) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
