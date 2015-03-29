class AddTrustLevelLockedColumn < ActiveRecord::Migration
  def change
    add_column :users, :trust_level_locked, :boolean, { default: false, null: false}

    reversible do |dir|
      dir.up do
        # Populate the column
        execute <<-SQL
          UPDATE users
          SET trust_level_locked = 't'
          WHERE trust_level = 4
        SQL
      end
      dir.down do
        # column is removed, no need to fill it
      end
    end
  end
end
