class RemoveNotNullFromEmail < ActiveRecord::Migration
  def self.up
    execute "ALTER TABLE invites ALTER COLUMN email DROP NOT NULL"
  end

  def self.down
    execute "ALTER TABLE invites ALTER COLUMN email SET NOT NULL"
  end
end
