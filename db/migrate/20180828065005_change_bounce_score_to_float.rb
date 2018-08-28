class ChangeBounceScoreToFloat < ActiveRecord::Migration[5.2]
  def change
    change_column :user_stats, :bounce_score, :float
  end
end
