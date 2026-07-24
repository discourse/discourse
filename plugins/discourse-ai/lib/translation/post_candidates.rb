# frozen_string_literal: true

module DiscourseAi
  module Translation
    class PostCandidates
      def self.progress_summary
        supported_locales = SiteSetting.content_localization_supported_locales.split("|")
        eligible_posts_sql = get.select(:id, :locale).to_sql

        sql = <<~SQL
          WITH #{DiscourseAi::Translation.supported_locale_bases_cte},
          eligible_posts AS (
            SELECT id,
                   locale,
                   split_part(
                     lower(replace(locale, '-', '_')), '_', 1
                   ) AS source_base
            FROM (#{eligible_posts_sql}) candidates
          ),
          localization_coverage AS (
            SELECT pl.post_id,
                   array_agg(
                     split_part(
                       lower(replace(pl.locale, '-', '_')), '_', 1
                     )
                   ) AS bases
            FROM post_localizations pl
            GROUP BY pl.post_id
          )
          SELECT
            COUNT(*)::bigint AS total_count,
            COUNT(*) FILTER (
              WHERE ep.locale IS NOT NULL
                AND supported.bases <@ (
                  COALESCE(lc.bases, ARRAY[]::text[]) || ep.source_base
                )
            )::bigint AS translated_count,
            COUNT(*) FILTER (
              WHERE ep.locale IS NULL
            )::bigint AS needs_language_detection_count
          FROM eligible_posts ep
          CROSS JOIN supported
          LEFT JOIN localization_coverage lc ON lc.post_id = ep.id
        SQL

        result = DB.query(sql, supported_locales:).first

        {
          target_type: "post",
          total_count: result.total_count,
          translated_count: result.translated_count,
          needs_language_detection_count: result.needs_language_detection_count,
        }
      end

      def self.progress_details
        main_posts =
          Post
            .where(
              "posts.created_at > ?",
              SiteSetting.ai_translation_backfill_max_age_days.days.ago,
            )
            .where(deleted_at: nil)
            .where.not(raw: [nil, ""])
            .where("LENGTH(posts.raw) <= ?", SiteSetting.ai_translation_max_post_length)

        main_posts =
          main_posts.where(
            "posts.user_id > 0",
          ) unless SiteSetting.ai_translation_include_bot_content

        main_posts = main_posts.joins(:topic)
        category_condition, category_params =
          DiscourseAi::Translation.category_scope_condition(category_column: "topics.category_id")
        main_posts =
          main_posts.where(
            "topics.archetype = :pm OR (#{category_condition})",
            category_params.merge(pm: Archetype.private_message),
          )

        case SiteSetting.ai_translation_personal_messages
        when "group"
          main_posts =
            main_posts.where(
              "topics.archetype != :pm OR topics.id IN (SELECT topic_id FROM topic_allowed_groups)",
              pm: Archetype.private_message,
            )
        when "none", nil
          main_posts = main_posts.where.not(topics: { archetype: Archetype.private_message })
        end

        banner_posts =
          Post
            .where(deleted_at: nil)
            .where.not(raw: [nil, ""])
            .where("LENGTH(posts.raw) <= ?", SiteSetting.ai_translation_max_post_length)
            .joins(:topic)
            .where(topics: { archetype: Archetype.banner, deleted_at: nil })
        banner_posts =
          banner_posts.where(
            "posts.user_id > 0",
          ) unless SiteSetting.ai_translation_include_bot_content

        eligible_posts_sql =
          "(#{main_posts.select("posts.id, posts.locale").to_sql}) UNION " \
            "(#{banner_posts.select("posts.id, posts.locale").to_sql})"
        supported_locales =
          ActiveRecord::Base.connection.quote(SiteSetting.content_localization_supported_locales)

        sql = <<~SQL
          WITH supported AS MATERIALIZED (
            SELECT DISTINCT ON (
                     split_part(lower(replace(locale, '-', '_')), '_', 1)
                   )
                   locale,
                   split_part(
                     lower(replace(locale, '-', '_')), '_', 1
                   ) AS base
            FROM unnest(string_to_array(#{supported_locales}, '|'))
              WITH ORDINALITY configured(locale, position)
            ORDER BY split_part(
                       lower(replace(locale, '-', '_')), '_', 1
                     ),
                     position
          ),
          eligible_posts AS MATERIALIZED (
            SELECT posts.id,
                   posts.locale,
                   split_part(
                     lower(replace(posts.locale, '-', '_')), '_', 1
                   ) AS base
            FROM (#{eligible_posts_sql}) posts
          ),
          totals AS (
            SELECT COUNT(*)::bigint AS total
            FROM eligible_posts
          ),
          source_locale_counts AS (
            SELECT base,
                   COUNT(*)::bigint AS count
            FROM eligible_posts
            WHERE locale IS NOT NULL
            GROUP BY base
          ),
          translated_counts AS (
            SELECT supported.base,
                   COUNT(DISTINCT posts.id)::bigint AS count
            FROM eligible_posts posts
            JOIN post_localizations localization
              ON localization.post_id = posts.id
            JOIN supported
              ON supported.base = split_part(
                lower(replace(localization.locale, '-', '_')), '_', 1
              )
            WHERE posts.locale IS NOT NULL
              AND posts.base <> supported.base
            GROUP BY supported.base
          )
          SELECT supported.locale,
                 COALESCE(translated.count, 0)::bigint AS translated_count,
                 (
                   totals.total -
                   COALESCE(source_locales.count, 0) -
                   COALESCE(translated.count, 0)
                 )::bigint AS pending_count,
                 (
                   totals.total -
                   COALESCE(source_locales.count, 0)
                 )::bigint AS eligible_count
          FROM supported
          CROSS JOIN totals
          LEFT JOIN translated_counts translated
            ON translated.base = supported.base
          LEFT JOIN source_locale_counts source_locales
            ON source_locales.base = supported.base
          ORDER BY supported.locale
        SQL

        {
          target_type: "post",
          locales:
            DB
              .query(sql)
              .map do |row|
                {
                  locale: row.locale,
                  translated_count: row.translated_count,
                  pending_count: row.pending_count,
                  eligible_count: row.eligible_count,
                }
              end,
        }
      end

      def self.needs_localization(limit:)
        locales = DiscourseAi::Translation.locales
        return [] if locales.blank?

        locale_map = {}
        locales.each { |l| locale_map[l.split("_").first] ||= l }

        target_locale_values = locale_map.map { |base, full| "('#{base}', '#{full}')" }.join(", ")

        base_sql = get.where.not(locale: nil).to_sql

        sql = <<~SQL
          SELECT ep.id AS post_id, target.target_locale
          FROM (#{base_sql}) ep
          JOIN (VALUES #{target_locale_values}) AS target(base_locale, target_locale)
            ON target.base_locale != split_part(ep.locale, '_', 1)
          WHERE NOT EXISTS (
            SELECT 1 FROM post_localizations pl
            WHERE pl.post_id = ep.id
              AND split_part(pl.locale, '_', 1) = target.base_locale
          )
          ORDER BY ep.updated_at DESC, target.target_locale
          LIMIT #{limit.to_i}
        SQL

        DB.query(sql).map { |r| [r.post_id, r.target_locale] }
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
            .where.not(raw: [nil, ""])
            .where("LENGTH(posts.raw) <= ?", SiteSetting.ai_translation_max_post_length)

        posts =
          posts.where("posts.user_id > 0") unless SiteSetting.ai_translation_include_bot_content

        posts = posts.joins(:topic)

        pm_scope = SiteSetting.ai_translation_personal_messages
        category_condition, category_params =
          DiscourseAi::Translation.category_scope_condition(category_column: "topics.category_id")

        posts =
          posts.where(
            "topics.archetype = :pm OR (#{category_condition})",
            category_params.merge(pm: Archetype.private_message),
          )

        # PM scope filter
        case pm_scope
        when "group"
          posts =
            posts.where(
              "topics.archetype != :pm OR topics.id IN (SELECT topic_id FROM topic_allowed_groups)",
              pm: Archetype.private_message,
            )
        when "none", nil
          posts = posts.where.not(topics: { archetype: Archetype.private_message })
        end

        # Always include posts from banner topics regardless of age or category filters
        banner_posts =
          Post
            .where(deleted_at: nil)
            .where.not(raw: [nil, ""])
            .where("LENGTH(posts.raw) <= ?", SiteSetting.ai_translation_max_post_length)
            .joins(:topic)
            .where(topics: { archetype: Archetype.banner, deleted_at: nil })
        banner_posts =
          banner_posts.where(
            "posts.user_id > 0",
          ) unless SiteSetting.ai_translation_include_bot_content
        posts = posts.or(banner_posts)

        posts
      end
    end
  end
end
