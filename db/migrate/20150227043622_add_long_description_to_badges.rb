class AddLongDescriptionToBadges < ActiveRecord::Migration[4.2]
  def change
    add_column :badges, :long_description, :text
  end
end
