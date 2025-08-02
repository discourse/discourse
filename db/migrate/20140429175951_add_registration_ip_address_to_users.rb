# frozen_string_literal: true

class AddRegistrationIpAddressToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :registration_ip_address, :inet
  end
end
