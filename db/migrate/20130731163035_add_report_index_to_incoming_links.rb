class AddReportIndexToIncomingLinks < ActiveRecord::Migration
  def change
    add_index :incoming_links, [:created_at, :user_id]
    add_index :incoming_links, [:created_at, :domain]
  end
end
