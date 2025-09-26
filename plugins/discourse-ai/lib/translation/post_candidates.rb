# frozen_string_literal: true

module DiscourseAi
  module Translation
    class PostCandidates
      CACHE_TTL = 1.hour

      # Returns the total number of candidates and the number of candidates that have a detected locale.
      # The values are cached and provides an overview of how many posts are eligible for translation and how many have been detected with a locale.
      # @return [Hash] a hash with keys :total and :posts_with_detected_locale
      def self.get_total_and_with_locale_count
        Discourse
          .cache
          .fetch(get_total_cache_key, expires_in: CACHE_TTL) do
            total, with_locale = total_and_with_locale_count
            return { total: 0, posts_with_detected_locale: 0 } if total.zero?
            { total:, posts_with_detected_locale: with_locale }
          end
      end

      # Returns the number of posts that have been translated, and the total number of posts that need translation for a given locale.
      # The total number of posts is based off candidates that already have a locale.
      # @param locale [String] the locale for which to calculate the completion percentage
      # @return [Hash] a hash with keys :done and :total
      def self.get_completion_all_locales
        Discourse
          .cache
          .fetch(get_completion_cache_key, expires_in: CACHE_TTL) { completion_all_locales }
      end

      def self.clear_completion_cache(locale)
        Discourse.cache.delete(get_completion_cache_key(locale))
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

      def self.total_and_with_locale_count
        DB.query_single(<<~SQL)
          WITH eligible_posts AS (
            #{get.to_sql}
          ),
          total_count AS (
            SELECT COUNT(*) AS count FROM eligible_posts
          ),
          has_locale_count AS (
            SELECT COUNT(DISTINCT p.id)
            FROM eligible_posts p
            WHERE p.locale IS NOT NULL
          )
          SELECT t.count AS total, d.count AS done
          FROM total_count t, has_locale_count d
        SQL
      end

      def self.completion_all_locales
        supported = SiteSetting.content_localization_supported_locales.split("|")
        values_rows = supported.map { |loc| "('#{loc}')" }.join(", ")

        sql = <<~SQL
          WITH supported AS (
            SELECT localestr, split_part(localestr, '_', 1) AS base
            FROM (VALUES #{values_rows}) AS t(localestr)
          ),
          eligible_posts AS (
            #{get.where("posts.locale IS NOT NULL").to_sql}
          ),
          total_count AS (
            SELECT COUNT(*)::bigint AS count FROM eligible_posts
          ),
          done_per_base AS (
            SELECT s.base,
                   COUNT(*)::bigint AS done
            FROM eligible_posts p
            JOIN supported s ON TRUE
            WHERE split_part(p.locale, '_', 1) = s.base
               OR EXISTS (
                    SELECT 1
                    FROM post_localizations pl
                    WHERE pl.post_id = p.id
                      AND split_part(pl.locale, '_', 1) = s.base
                  )
            GROUP BY s.base
          )
          SELECT s.localestr AS locale,
                 COALESCE(d.done, 0) AS done,
                 t.count AS total
          FROM supported s
          LEFT JOIN done_per_base d ON d.base = s.base
          CROSS JOIN total_count t
        SQL

        DB.query(sql).map { |r| { locale: r.locale, done: r.done, total: r.total } }
      end

      def self.cache_key_for_type
        "discourse_ai::translation::post_candidates"
      end

      def self.get_total_cache_key
        "#{cache_key_for_type}_total"
      end

      def self.get_completion_cache_key
        "#{cache_key_for_type}_completion_all_locales"
      end
    end
  end
end
