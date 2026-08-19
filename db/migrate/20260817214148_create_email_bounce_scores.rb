# frozen_string_literal: true

class CreateEmailBounceScores < ActiveRecord::Migration[8.0]
  def change
    create_table :email_bounce_scores do |t|
      t.string :email, limit: 513, null: false
      t.float :bounce_score, null: false, default: 0
      t.datetime :reset_bounce_score_after, null: false
      t.timestamps
    end

    add_index :email_bounce_scores, :email, unique: true

    # seed the addresses that are in bad standing right now, so that upgrading
    # doesn't lift every suppression already in effect
    up_only { execute <<~SQL }
        INSERT INTO email_bounce_scores
          (email, bounce_score, reset_bounce_score_after, created_at, updated_at)
        SELECT
          lower(user_emails.email),
          user_stats.bounce_score,
          user_stats.reset_bounce_score_after,
          now(),
          now()
        FROM user_stats
        INNER JOIN user_emails
          ON user_emails.user_id = user_stats.user_id AND user_emails.primary
        WHERE user_stats.bounce_score > 0
          AND user_stats.reset_bounce_score_after IS NOT NULL
      SQL
  end
end
