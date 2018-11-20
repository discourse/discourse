class AddAllTimeAndOpLikesToTopTopics < ActiveRecord::Migration[4.2]
  def change
    add_column :top_topics, :all_score, :float, default: 0
    [:daily, :weekly, :monthly, :yearly].each do |period|
      column = "#{period}_op_likes_count"
      add_column :top_topics, column, :integer, default: 0, null: false
      add_index :top_topics, [column]
    end
  end
end
