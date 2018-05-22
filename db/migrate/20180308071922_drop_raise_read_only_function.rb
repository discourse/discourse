class DropRaiseReadOnlyFunction < ActiveRecord::Migration[5.1]
  def up
    ActiveRecord::Base.exec_sql(
      "DROP FUNCTION IF EXISTS raise_read_only() CASCADE;"
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
