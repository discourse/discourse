class AddBakedVersionToPost < ActiveRecord::Migration
  def change
    add_column :posts, :baked_version, :integer
  end
end
