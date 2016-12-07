class AddBioToGroups < ActiveRecord::Migration
  def change
    add_column :groups, :bio_raw, :text
    add_column :groups, :bio_cooked, :text
  end
end
