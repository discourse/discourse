class AddViaEmailToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :via_email, :boolean, default: false, null: false
  end
end
