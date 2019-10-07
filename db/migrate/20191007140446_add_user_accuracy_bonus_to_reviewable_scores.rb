# frozen_string_literal: true

class AddUserAccuracyBonusToReviewableScores < ActiveRecord::Migration[6.0]
  def up
    # Add user_accuracy_bonus to reviewable_scores
    execute <<~SQL
    ALTER TABLE reviewable_scores
    ADD COLUMN user_accuracy_bonus float
    DEFAULT 0
    SQL

    # Set user_accuracy_bonus = score - user.trust_level - 1
    execute <<~SQL
    UPDATE reviewable_scores
    SET user_accuracy_bonus = score - (
    SELECT trust_level
    FROM users
    WHERE users.id = reviewable_scores.user_id
    ) - 1;
    SQL
  end

  def down
    # Remove user_accuracy_bonus from reviewable_scores
    execute <<~SQL
    ALTER TABLE reviewable_scores
    DROP user_accuracy_bonus
    SQL
  end
end
