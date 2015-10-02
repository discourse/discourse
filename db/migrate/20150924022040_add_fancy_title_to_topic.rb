class AddFancyTitleToTopic < ActiveRecord::Migration
  def change
    add_column :topics, :fancy_title, :string, limit: 400, null: true
  end
end
