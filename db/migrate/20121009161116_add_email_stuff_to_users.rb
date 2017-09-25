class AddEmailStuffToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :last_emailed_at, :datetime, null: true
    add_column :users, :email_digests, :boolean, null: false, default: true
  end
end
