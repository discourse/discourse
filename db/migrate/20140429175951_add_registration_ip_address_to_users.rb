class AddRegistrationIpAddressToUsers < ActiveRecord::Migration
  def change
    add_column :users, :registration_ip_address, :inet
  end
end
