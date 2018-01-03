class AddApplicationRequests < ActiveRecord::Migration[4.2]
  def change
    create_table :application_requests do |t|
      t.date :date, null: false
      t.integer :req_type, null: false
      t.integer :count, null: false, default: 0
    end

    add_index :application_requests, [:date, :req_type], unique: true
  end
end
