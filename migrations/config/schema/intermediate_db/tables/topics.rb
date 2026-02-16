# frozen_string_literal: true

Migrations::Database::Schema.table :topics do
  ignore :last_posted_at
  ignore :last_post_user_id
  ignore :reply_count
  ignore :featured_user1_id
  ignore :featured_user2_id
  ignore :featured_user3_id
  ignore :featured_user4_id
  ignore :image_upload_id
  ignore :highest_post_number
  ignore :like_count
  ignore :locale
  ignore :incoming_link_count
  ignore :moderator_posts_count
  ignore :bumped_at
  ignore :has_summary
  ignore :notify_moderators_count
  ignore :spam_count
  ignore :percent_rank
  ignore :posts_count
  ignore :score
  ignore :slug
  ignore :participant_count
  ignore :word_count
  ignore :excerpt
  ignore :fancy_title
  ignore :highest_staff_post_number
  ignore :reviewable_score
  ignore :slow_mode_seconds

  index [:archetype], name: :index_topics_on_archetype
end
