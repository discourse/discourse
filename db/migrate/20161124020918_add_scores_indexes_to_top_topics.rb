class AddScoresIndexesToTopTopics < ActiveRecord::Migration[4.2]
  def change
    add_index :top_topics, :daily_score
    add_index :top_topics, :weekly_score
    add_index :top_topics, :monthly_score
    add_index :top_topics, :yearly_score
    add_index :top_topics, :all_score
  end
end
