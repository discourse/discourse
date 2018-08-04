class AddSkipBumpToTopics < ActiveRecord::Migration[5.2]
  def change
    add_column :topics, :skip_bump, :boolean
  end
end
