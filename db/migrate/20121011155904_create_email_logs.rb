class CreateEmailLogs < ActiveRecord::Migration
  def change
    create_table :email_logs do |t|
      t.string :to_address, null: false
      t.string :email_type, null: false
      t.integer :user_id, null: true
      t.timestamps
    end

    add_index :email_logs, :created_at, order: {created_at: :desc}
    add_index :email_logs, [:user_id, :created_at], order: {created_at: :desc}
  end
end
