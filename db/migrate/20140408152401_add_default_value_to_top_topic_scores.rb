class AddDefaultValueToTopTopicScores < ActiveRecord::Migration
  def change
    [:daily, :weekly, :monthly, :yearly].each do |period|
      change_column_default :top_topics, "#{period}_score".to_sym, 0
    end
  end
end
