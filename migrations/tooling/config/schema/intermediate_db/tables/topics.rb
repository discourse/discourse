# frozen_string_literal: true

Migrations::Tooling::Schema.table :topics do
  index :archetype

  # The destination regenerates its own slug from the title, but the SOURCE
  # slug is what a slug-only `/t/<slug>` link in a post body carries — the
  # resolver looks it up here to remap such links. Nullable because not every
  # source has slugs; resolution then finds nothing and the link stays as
  # written.
  column :slug, required: false

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
         :moderator_posts_count,
         :notify_moderators_count,
         :participant_count,
         :percent_rank,
         :posts_count,
         :reply_count,
         :reviewable_score,
         :score,
         :spam_count,
         :word_count,
         reason: "Calculated columns"
end
