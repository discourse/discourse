class AddTopicAllowedGroups < ActiveRecord::Migration[4.2]
  def change
    create_table :topic_allowed_groups, force: true do |t|
      # oops
      t.integer :group_id, :integer, null: false
      t.integer :topic_id, :integer, null: false
    end

    add_index :topic_allowed_groups, [:group_id, :topic_id], unique: true
    add_index :topic_allowed_groups, [:topic_id, :group_id], unique: true
  end
end
