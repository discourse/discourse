class AddAdminFlagToUsers < ActiveRecord::Migration
  def change
    add_column :users, :admin, :boolean, default: false, null: false
    add_column :users, :moderator, :boolean, default: false, null: false

    # Make all of us admins
    execute "UPDATE users SET admin = TRUE where lower(username) in ('eviltrout', 'codinghorror', 'sam', 'hanzo')"
  end
end
