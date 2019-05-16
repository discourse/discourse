# frozen_string_literal: true

class AddBadgeGroupings < ActiveRecord::Migration[4.2]
  def change
    create_table :badge_groupings do |t|
      t.string :name, null: false
      t.string :description, null: false
      t.integer :position, null: false
      t.timestamps null: false
    end

    add_column :badges, :badge_grouping_id, :integer

  end
end
