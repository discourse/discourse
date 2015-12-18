class AddIncomingEmailToGroups < ActiveRecord::Migration
  def change
    add_column :groups, :incoming_email, :string, null: true
    add_index :groups, :incoming_email, unique: true
  end
end
