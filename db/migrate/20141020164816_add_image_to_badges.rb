class AddImageToBadges < ActiveRecord::Migration
  def change
    add_column :badges, :image, :string, limit: 255
  end
end
