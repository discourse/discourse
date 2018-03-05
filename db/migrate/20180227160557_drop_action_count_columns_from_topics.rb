class DropActionCountColumnsFromTopics < ActiveRecord::Migration[5.1]
  def up
    # Defer dropping of the columns
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
