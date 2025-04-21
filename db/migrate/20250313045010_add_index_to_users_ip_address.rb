# frozen_string_literal: true

class AddIndexToUsersIpAddress < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    remove_index :users,
                 :ip_address,
                 algorithm: :concurrently,
                 name: "idx_users_ip_address",
                 if_exists: true

    add_index :users, :ip_address, algorithm: :concurrently, name: "idx_users_ip_address"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
