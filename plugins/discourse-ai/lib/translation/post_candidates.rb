# frozen_string_literal: true

module DiscourseAi
  module Translation
    class PostCandidates
      # Returns the number of posts that have been translated, and the total number of posts that need translation for a given locale.
      # The total number of posts is based off candidates that already have a locale.
      # Also returns aggregate counts for total eligible posts and posts with detected locale.
      # @return [Hash] a hash with keys :translation_progress (array), :total (integer), and :posts_with_detected_locale (integer)
      def self.get_completion_all_locales
        completion_all_locales
      end

      private

      # all posts that are eligible for translation based on site settings,
      # including those without locale detected yet.
      def self.get
        posts =
          Post
            .where(
              "posts.created_at > ?",
              SiteSetting.ai_translation_backfill_max_age_days.days.ago,
            )
            .where(deleted_at: nil)
            .where("posts.user_id > 0")
            .where.not(raw: [nil, ""])
            .where("LENGTH(posts.raw) <= ?", SiteSetting.ai_translation_max_post_length)

        posts = posts.joins(:topic)
        if SiteSetting.ai_translation_backfill_limit_to_public_content
          # exclude all PMs
          # and only include posts from public categories
          posts =
            posts
              .where.not(topics: { archetype: Archetype.private_message })
              .where(topics: { category_id: Category.where(read_restricted: false).select(:id) })
        else
          # all regular topics, and group PMs
          posts =
            posts.where(
              "topics.archetype != ? OR topics.id IN (SELECT topic_id FROM topic_allowed_groups)",
              Archetype.private_message,
            )
        end
      end

      def self.completion_all_locales
        supported = SiteSetting.content_localization_supported_locales.split("|")
        values_rows = supported.map { |loc| "('#{loc}')" }.join(", ")

        sql = <<~SQL
          WITH supported AS (
            SELECT localestr,
                   split_part(localestr, '_', 1) AS base
            FROM (VALUES #{values_rows}) AS t(localestr)
          ),
          all_eligible_posts AS (
            #{get.to_sql}
          ),
          total_eligible_count AS (
            SELECT COUNT(*)::bigint AS count FROM all_eligible_posts
          ),
          eligible_posts AS (
            SELECT * FROM all_eligible_posts WHERE locale IS NOT NULL
          ),
          all_posts_count AS (
            SELECT COUNT(*)::bigint AS count FROM eligible_posts
          ),
          non_target_locale_counts AS (
            SELECT s.base,
                   COUNT(*)::bigint AS count
            FROM eligible_posts p
            CROSS JOIN supported s
            WHERE split_part(p.locale, '_', 1) != s.base
            GROUP BY s.base
          ),
          done_per_base AS (
            SELECT s.base,
                   COUNT(*)::bigint AS done
            FROM eligible_posts p
            JOIN supported s ON TRUE
            WHERE split_part(p.locale, '_', 1) != s.base AND EXISTS (
              SELECT 1
              FROM post_localizations pl
              WHERE pl.post_id = p.id
                AND split_part(pl.locale, '_', 1) = s.base
            )
            GROUP BY s.base
          )
          SELECT s.localestr AS locale,
                 COALESCE(d.done, 0) AS done,
                 COALESCE(ntl.count, 0) AS total,
                 (SELECT count FROM total_eligible_count) AS total_eligible,
                 (SELECT count FROM all_posts_count) AS posts_with_locale
          FROM supported s
          LEFT JOIN done_per_base d ON d.base = s.base
          LEFT JOIN non_target_locale_counts ntl ON ntl.base = s.base
        SQL

        results = DB.query(sql)

        if results.empty?
          return { translation_progress: [], total: 0, posts_with_detected_locale: 0 }
        end

        # Extract aggregate counts from first row (same for all rows)
        total_eligible = results.first.total_eligible
        posts_with_locale = results.first.posts_with_locale

        # Build per-locale progress array
        translation_progress =
          results.map { |r| { locale: r.locale, done: r.done, total: r.total } }

        translation_progress =
          translation_progress.sort_by do |r|
            percentage = r[:total] > 0 ? r[:done].to_f / r[:total] : 0
            -percentage
          end

        {
          translation_progress: translation_progress,
          total: total_eligible,
          posts_with_detected_locale: posts_with_locale,
        }
      end
    end
  end
end
