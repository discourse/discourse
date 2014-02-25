class AddSingleSignOnRecords < ActiveRecord::Migration
  def change
    create_table :single_sign_on_records do |t|
      t.integer :user_id, null: false
      t.string :external_id, null: false, length: 255
      t.text :last_payload, null: false
      t.timestamps
    end

    add_index :single_sign_on_records, :external_id, unique: true
  end
end
