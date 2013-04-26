class AllowNullsInIncomingLinks < ActiveRecord::Migration
  def change
    change_column :incoming_links, :referer, :string, limit:1000, null: true
    change_column :incoming_links, :domain, :string, limit:100, null: true
  end
end
