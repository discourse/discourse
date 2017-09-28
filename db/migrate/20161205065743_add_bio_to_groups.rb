class AddBioToGroups < ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :bio_raw, :text
    add_column :groups, :bio_cooked, :text
  end
end
