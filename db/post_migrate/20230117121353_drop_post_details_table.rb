# frozen_string_literal: true

require "migration/table_dropper"

# post_details has been replaced by post_custom_fields long time ago
# but the table never got dropped
class DropPostDetailsTable < ActiveRecord::Migration[7.0]
  DROPPED_TABLES ||= %i[post_details]

  def up
    DROPPED_TABLES.each { |table| Migration::TableDropper.execute_drop(table) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
