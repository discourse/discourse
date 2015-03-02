class AddLongDescriptionToBadges < ActiveRecord::Migration
  def change
    add_column :badges, :long_description, :text
  end
end
