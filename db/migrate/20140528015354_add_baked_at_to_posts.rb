class AddBakedAtToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :baked_at, :datetime
  end
end
