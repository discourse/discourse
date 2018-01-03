class AddBakedVersionToPost < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :baked_version, :integer
  end
end
