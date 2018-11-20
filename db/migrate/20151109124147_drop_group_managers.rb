class DropGroupManagers < ActiveRecord::Migration[4.2]
  def up
    # old data under old structure
    execute "UPDATE group_users SET owner = true
      WHERE exists (SELECT 1 FROM group_managers m
                    WHERE m.group_id = group_users.group_id AND
                          m.user_id = group_users.user_id)"

    drop_table "group_managers"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
