class AddImageToBadges < ActiveRecord::Migration[4.2]
  def change
    add_column :badges, :image, :string, limit: 255
  end
end
