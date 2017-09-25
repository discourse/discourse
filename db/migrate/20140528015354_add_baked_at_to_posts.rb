class AddBakedAtToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :baked_at, :datetime
  end
end
