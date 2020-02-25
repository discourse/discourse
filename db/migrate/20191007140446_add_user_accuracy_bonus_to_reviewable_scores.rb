# frozen_string_literal: true

class AddUserAccuracyBonusToReviewableScores < ActiveRecord::Migration[6.0]
  def up
    # Add user_accuracy_bonus to reviewable_scores
    add_column :reviewable_scores, :user_accuracy_bonus, :float, default: 0, null: false

    # Set user_accuracy_bonus = score - user.trust_level - 1
    execute <<~SQL
    UPDATE reviewable_scores
    SET user_accuracy_bonus = score - users.trust_level - 1
    FROM users
    WHERE reviewable_scores.user_id = users.id
    SQL
  end

  def down
    # Remove user_accuracy_bonus from reviewable_scores
    remove_column :reviewable_scores, :user_accuracy_bonus
  end
end
