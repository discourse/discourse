class CreateBlockedEmails < ActiveRecord::Migration[4.2]
  def change
    create_table :blocked_emails do |t|
      t.string :email, null: false
      t.integer :action_type, null: false
      t.integer :match_count, null: false, default: 0
      t.datetime :last_match_at
      t.timestamps null: false
    end
    add_index :blocked_emails, :email, unique: true
  end
end
