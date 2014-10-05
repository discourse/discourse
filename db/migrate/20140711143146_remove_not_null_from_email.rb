class RemoveNotNullFromEmail < ActiveRecord::Migration
  def up
    execute "ALTER TABLE invites ALTER COLUMN email DROP NOT NULL"
  end

  def down
    execute "ALTER TABLE invites ALTER COLUMN email SET NOT NULL"
  end
end
