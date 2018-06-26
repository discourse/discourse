class DropEmailFromUsers < ActiveRecord::Migration[5.1]
  def up
    # Defer dropping of the columns until the new application code has been deployed.
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
