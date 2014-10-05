class AddViaEmailToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :via_email, :boolean, default: false, null: false
  end
end
