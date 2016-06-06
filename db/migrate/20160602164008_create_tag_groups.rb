class CreateTagGroups < ActiveRecord::Migration
  def change
    create_table :tag_groups do |t|
      t.string :name,       null: false
      t.integer :tag_count, null: false, default: 0
      t.timestamps
    end

    create_table :tag_group_memberships do |t|
      t.references :tag,       null: false
      t.references :tag_group, null: false
      t.timestamps
    end

    add_index :tag_group_memberships, [:tag_group_id, :tag_id], unique: true
  end
end
