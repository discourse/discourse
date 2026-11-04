# frozen_string_literal: true

module Jobs
  class EnqueueSuspectUsers < ::Jobs::Scheduled
    every 2.hours

    UNVIEWED_READS_MAX_ACCOUNT_AGE = 7.days
    UNVIEWED_READS_MIN_READS = 20
    UNVIEWED_READS_MIN_RATIO = 0.9

    def execute(_args)
      return unless SiteSetting.approve_suspect_users
      return if SiteSetting.must_approve_users

      enqueue(profile_without_reading_users, :suspect_user)
      enqueue(unviewed_topic_readers, :reads_without_topic_views)
    end

    private

    def enqueue(users, reason)
      users.each do |user|
        reviewable =
          ReviewableUser.needs_review!(
            target: user,
            created_by: Discourse.system_user,
            reviewable_by_moderator: true,
            payload: ReviewableUser.payload_for(user),
          )

        if reviewable.created_new
          reviewable.add_score(
            Discourse.system_user,
            ReviewableScore.types[:needs_approval],
            reason:,
            force_review: true,
          )
        end
      end
    end

    def candidates
      User
        .distinct
        .activated
        .human_users
        .not_suspended
        .where(approved: false)
        .joins(:user_stat)
        .joins("LEFT OUTER JOIN reviewables r ON r.target_id = users.id AND r.target_type = 'User'")
        .where("r.id IS NULL")
    end

    def profile_without_reading_users
      candidates
        .joins(:user_profile)
        .includes(:user_profile, :uploaded_avatar)
        .where("users.created_at <= ? AND users.created_at >= ?", 1.day.ago, 6.months.ago)
        .where("LENGTH(COALESCE(user_profiles.bio_raw, user_profiles.website, '')) > 0")
        .where(
          "user_stats.posts_read_count <= 1 OR user_stats.topics_entered <= 1 OR user_stats.time_read < ?",
          1.minute.to_i,
        )
        .joins(<<~SQL)
          LEFT OUTER JOIN (
            SELECT user_id
            FROM user_custom_fields
            WHERE user_custom_fields.name = 'import_id'
          ) AS ucf ON ucf.user_id = users.id
        SQL
        .where("ucf.user_id IS NULL")
        .limit(10)
    end

    # The web client records a topic view before it can report reads, so new
    # accounts whose reads are almost all in unopened topics are sending read
    # timings from a script.
    def unviewed_topic_readers
      candidates
        .includes(:user_profile, :uploaded_avatar)
        .where("users.created_at >= ?", UNVIEWED_READS_MAX_ACCOUNT_AGE.ago)
        .where(
          "user_stats.post_count = 0 AND user_stats.posts_read_count >= ?",
          UNVIEWED_READS_MIN_READS,
        )
        .where(<<~SQL, min_reads: UNVIEWED_READS_MIN_READS, min_ratio: UNVIEWED_READS_MIN_RATIO)
          (
            SELECT
              COUNT(*) >= :min_reads AND
              COUNT(*) FILTER (
                WHERE NOT EXISTS (
                  SELECT 1
                  FROM topic_views tv
                  WHERE tv.user_id = pt.user_id AND tv.topic_id = pt.topic_id
                )
              ) >= :min_ratio * COUNT(*)
            FROM post_timings pt
            JOIN topics t ON t.id = pt.topic_id
            WHERE pt.user_id = users.id
              AND t.archetype = 'regular'
              AND t.deleted_at IS NULL
          )
        SQL
        .limit(50)
    end
  end
end
