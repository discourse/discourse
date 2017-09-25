class AddIncomingEmailToGroups < ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :incoming_email, :string, null: true
    add_index :groups, :incoming_email, unique: true
  end
end
