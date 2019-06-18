# frozen_string_literal: true

class DropRaiseReadOnlyFunction < ActiveRecord::Migration[5.1]
  def up
    DB.exec(
      "DROP FUNCTION IF EXISTS raise_read_only() CASCADE;"
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
