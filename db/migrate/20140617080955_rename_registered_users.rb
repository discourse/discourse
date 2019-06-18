# frozen_string_literal: true

class RenameRegisteredUsers < ActiveRecord::Migration[4.2]
  def change
    execute "update groups set name = 'trust_level_0' where name = 'registered_users' and id = 10"
  end
end
