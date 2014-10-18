class AddRawEmailToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :raw_email, :text
  end
end
