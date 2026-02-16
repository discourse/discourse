# frozen_string_literal: true

Migrations::Database::Schema.table :topics do
  ignore :last_posted_at, "TODO: add reason"
  ignore :last_post_user_id, "TODO: add reason"
  ignore :reply_count, "TODO: add reason"
  ignore :featured_user1_id, "TODO: add reason"
  ignore :featured_user2_id, "TODO: add reason"
  ignore :featured_user3_id, "TODO: add reason"
  ignore :featured_user4_id, "TODO: add reason"
  ignore :image_upload_id, "TODO: add reason"
  ignore :highest_post_number, "TODO: add reason"
  ignore :like_count, "TODO: add reason"
  ignore :locale, "TODO: add reason"
  ignore :incoming_link_count, "TODO: add reason"
  ignore :moderator_posts_count, "TODO: add reason"
  ignore :bumped_at, "TODO: add reason"
  ignore :has_summary, "TODO: add reason"
  ignore :notify_moderators_count, "TODO: add reason"
  ignore :spam_count, "TODO: add reason"
  ignore :percent_rank, "TODO: add reason"
  ignore :posts_count, "TODO: add reason"
  ignore :score, "TODO: add reason"
  ignore :slug, "TODO: add reason"
  ignore :participant_count, "TODO: add reason"
  ignore :word_count, "TODO: add reason"
  ignore :excerpt, "TODO: add reason"
  ignore :fancy_title, "TODO: add reason"
  ignore :highest_staff_post_number, "TODO: add reason"
  ignore :reviewable_score, "TODO: add reason"
  ignore :slow_mode_seconds, "TODO: add reason"

  index [:archetype], name: :index_topics_on_archetype
end
