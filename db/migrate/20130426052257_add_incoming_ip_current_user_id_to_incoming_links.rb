class AddIncomingIpCurrentUserIdToIncomingLinks < ActiveRecord::Migration
  def change
    add_column :incoming_links, :ip_address, :inet
    add_column :incoming_links, :current_user_id, :int
  end
end
