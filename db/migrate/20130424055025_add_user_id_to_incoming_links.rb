class AddUserIdToIncomingLinks < ActiveRecord::Migration
  def change
    add_column :incoming_links, :user_id, :integer
  end
end
