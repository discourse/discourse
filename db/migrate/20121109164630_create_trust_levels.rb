class CreateTrustLevels < ActiveRecord::Migration
  def change
    create_table :trust_levels do |t|
      t.string :name_key, null: false
      t.timestamps
    end

    add_column :users, :trust_level_id, :integer, default: 1, null: false
  end
end
