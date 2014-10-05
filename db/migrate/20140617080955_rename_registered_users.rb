class RenameRegisteredUsers < ActiveRecord::Migration
  def change
    execute "update groups set name = 'trust_level_0' where name = 'registered_users' and id = 10"
  end
end
