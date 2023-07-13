# frozen_string_literal: true

class CreateUserIpAddressHistories < ActiveRecord::Migration[6.0]
  def up
    create_table :user_ip_address_histories do |t|
      t.integer :user_id, null: false
      t.inet :ip_address, null: false

      t.timestamps
    end

    add_index :user_ip_address_histories, %i[user_id ip_address], unique: true
  end

  def down
    drop_table :user_ip_address_histories
  end
end
