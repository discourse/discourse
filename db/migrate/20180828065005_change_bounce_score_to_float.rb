# frozen_string_literal: true

class ChangeBounceScoreToFloat < ActiveRecord::Migration[5.2]
  def up
    change_column :user_stats, :bounce_score, :float
  end

  def down
    change_column :user_stats, :bounce_score, :integer
  end
end
