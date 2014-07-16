class AddBadgeGroupings < ActiveRecord::Migration
  def change
    create_table :badge_groupings do |t|
      t.string :name, null: false
      t.string :description, null: false
      t.integer :position, null: false
      t.timestamps
    end

    add_column :badges, :badge_grouping_id, :integer

  end
end
