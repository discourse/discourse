class RemoveNotNullFromEmail < ActiveRecord::Migration[4.2]
  def up
    execute "ALTER TABLE invites ALTER COLUMN email DROP NOT NULL"
  end

  def down
    execute "ALTER TABLE invites ALTER COLUMN email SET NOT NULL"
  end
end
