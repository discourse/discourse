class AddScoresToTopTopics < ActiveRecord::Migration
  def change
    TopTopic.periods.each do |period|
      add_column :top_topics, "#{period}_score".to_sym, :float
    end
  end
end
