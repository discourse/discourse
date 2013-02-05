class AddIncomingLinkCountToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :incoming_link_count, :integer, default: 0, null: false
  end
end
