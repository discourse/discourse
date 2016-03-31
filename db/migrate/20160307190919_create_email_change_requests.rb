class CreateEmailChangeRequests < ActiveRecord::Migration
  def change
    create_table :email_change_requests do |t|
      t.integer :user_id, null: false
      t.string :old_email, length: 513, null: false
      t.string :new_email, length: 513, null: false
      t.integer :old_email_token_id, null: true
      t.integer :new_email_token_id, null: true
      t.integer :change_state, null: false
      t.timestamps null: false
    end

    add_index :email_change_requests, :user_id
  end
end
