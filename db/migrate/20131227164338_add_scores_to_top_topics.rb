class AddScoresToTopTopics < ActiveRecord::Migration
  def change
    [:daily, :weekly, :monthly, :yearly].each do |period|
      add_column :top_topics, "#{period}_score".to_sym, :float
    end
  end
end
