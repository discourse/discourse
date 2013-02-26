class CreateEmailTokens < ActiveRecord::Migration
  def change
    create_table :email_tokens do |t|
      t.references :user, null: false
      t.string :email, null: false
      t.string :token, null: false
      t.boolean :confirmed, null: false, default: false
      t.boolean :expired, null: false, default: false
      t.timestamps
    end
    add_index :email_tokens, :token, unique: true
  end
end
