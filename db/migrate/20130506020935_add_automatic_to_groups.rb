class AddAutomaticToGroups < ActiveRecord::Migration[4.2]
  def up
    add_column :groups, :automatic, :boolean, default: false, null: false

    # all numbers below 100 are reserved for automatic
    execute <<SQL
    ALTER SEQUENCE groups_id_seq START WITH 100
SQL
  end

  def down
    remove_column :groups, :automatic
  end
end
