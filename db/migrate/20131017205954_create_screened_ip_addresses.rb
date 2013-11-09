class CreateScreenedIpAddresses < ActiveRecord::Migration
  def change
    create_table :screened_ip_addresses do |t|
      t.column :ip_address, :inet, null: false
      t.integer :action_type, null: false
      t.integer :match_count, null: false, default: 0
      t.datetime :last_match_at
      t.timestamps
    end
    add_index :screened_ip_addresses, :ip_address, unique: true
    add_index :screened_ip_addresses, :last_match_at
  end
end
