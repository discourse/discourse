# frozen_string_literal: true

class DropGroupsSmtpSsl < ActiveRecord::Migration[7.1]
  DROPPED_COLUMNS = { groups: %i[smtp_ssl] }.freeze

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
