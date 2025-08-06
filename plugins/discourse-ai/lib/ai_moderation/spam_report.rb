# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    class SpamReport
      def self.generate(min_date: 1.week.ago)
        spam_status = [Reviewable.statuses[:approved], Reviewable.statuses[:deleted]]
        ham_status = [Reviewable.statuses[:rejected], Reviewable.statuses[:ignored]]

        sql = <<~SQL
          WITH spam_stats AS (
            SELECT
              asl.reviewable_id,
              asl.post_id,
              asl.is_spam,
              r.status as reviewable_status,
              CASE WHEN EXISTS (
                SELECT 1 FROM reviewable_scores rs
                JOIN reviewables r1 ON r1.id = rs.reviewable_id
                WHERE r1.target_id = asl.post_id
                AND r1.target_type = 'Post'
                AND rs.reviewable_score_type = :spam_score_type
                AND NOT is_spam
                AND r1.status IN (:spam)
              ) THEN true ELSE false END AS missed_spam
            FROM ai_spam_logs asl
            LEFT JOIN reviewables r ON r.id = asl.reviewable_id
            WHERE asl.created_at > :min_date
          )
          SELECT
            COUNT(*) AS scanned_count,
            SUM(CASE WHEN is_spam THEN 1 ELSE 0 END) AS spam_detected,
            COUNT(CASE WHEN reviewable_status IN (:ham) THEN 1 END) AS false_positives,
            COUNT(CASE WHEN missed_spam THEN 1 END) AS false_negatives
          FROM spam_stats
        SQL

        DB.query(
          sql,
          spam: spam_status,
          ham: ham_status,
          min_date: min_date,
          spam_score_type: ReviewableScore.types[:spam],
        ).first
      end
    end
  end
end
