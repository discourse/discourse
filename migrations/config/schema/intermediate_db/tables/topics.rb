# frozen_string_literal: true

Migrations::Database::Schema.table :topics do
  index :archetype

  ignore :bumped_at,
         :excerpt,
         :fancy_title,
         :featured_user1_id,
         :featured_user2_id,
         :featured_user3_id,
         :featured_user4_id,
         :has_summary,
         :highest_post_number,
         :highest_staff_post_number,
         :image_upload_id,
         :incoming_link_count,
         :last_post_user_id,
         :last_posted_at,
         :like_count,
         :locale,
         :moderator_posts_count,
         :notify_moderators_count,
         :participant_count,
         :percent_rank,
         :posts_count,
         :reply_count,
         :reviewable_score,
         :score,
         :slug,
         :slow_mode_seconds,
         :spam_count,
         :word_count,
         reason: "Calculated columns"
end
