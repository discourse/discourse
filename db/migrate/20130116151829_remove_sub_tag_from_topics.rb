class RemoveSubTagFromTopics < ActiveRecord::Migration
  def up
    remove_column :topics, :sub_tag
  end

  def down
    add_column :topics, :sub_tag, :string
  end
end
