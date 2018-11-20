class AddWebsiteToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :website, :string
  end
end
