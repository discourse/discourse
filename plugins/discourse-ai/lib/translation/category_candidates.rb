# frozen_string_literal: true

module DiscourseAi
  module Translation
    class CategoryCandidates < BaseCandidates
      def self.get
        categories = Category.all
        if SiteSetting.ai_translation_backfill_limit_to_public_content
          categories = categories.where(read_restricted: false)
        end
        categories
      end

      private

      def self.calculate_completion_per_locale(locale)
        base_locale = "#{locale.split("_").first}%"
        sql = <<~SQL
          WITH eligible_categories AS (
            #{get.to_sql}
          ),
          total_count AS (
            SELECT COUNT(*) AS count FROM eligible_categories
          ),
          done_count AS (
            SELECT COUNT(DISTINCT c.id)
            FROM eligible_categories c
            LEFT JOIN category_localizations cl ON c.id = cl.category_id AND cl.locale LIKE :base_locale
            WHERE c.locale LIKE :base_locale OR cl.category_id IS NOT NULL
          )
          SELECT d.count AS done, t.count AS total
          FROM total_count t, done_count d
        SQL

        DB.query_single(sql, base_locale: "#{base_locale}%")
      end

      def self.completion_cache_key_for_type
        "discourse_ai::translation::category_candidates"
      end
    end
  end
end
