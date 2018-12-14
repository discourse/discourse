class CreateUserAssociatedAccounts < ActiveRecord::Migration[5.2]
  def change
    create_table :user_associated_accounts do |t|
      t.string :provider_name, null: false
      t.string :provider_uid, null: false
      t.integer :user_id, null: false
      t.datetime :last_used, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.jsonb :info, null: false, default: {}
      t.jsonb :credentials, null: false, default: {}
      t.jsonb :extra, null: false, default: {}

      t.timestamps
    end

    add_index :user_associated_accounts, [:provider_name, :provider_uid], unique: true, name: 'associated_accounts_provider_uid'
    add_index :user_associated_accounts, [:provider_name, :user_id], unique: true, name: 'associated_accounts_provider_user'
  end
end
