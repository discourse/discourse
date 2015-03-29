class AddLastRedirectedToTopAtToUsers < ActiveRecord::Migration
  def change
    add_column :users, :last_redirected_to_top_at, :datetime
  end
end
