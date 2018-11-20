class AddLastRedirectedToTopAtToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :last_redirected_to_top_at, :datetime
  end
end
