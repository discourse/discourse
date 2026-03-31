# frozen_string_literal: true

module DiscourseAi
  module Translation
    class CategoryCandidates < BaseCandidates
      private

      # all categories that are eligible for translation based on site settings,
      # including those without locale detected yet.
      def self.get
        target_category_ids = SiteSetting.ai_translation_target_categories
        if target_category_ids.present?
          Category.where(id: target_category_ids.split("|").map(&:to_i))
        else
          Category.none
        end
      end

      def self.calculate_completion_per_locale(locale)
        base_locale = "#{locale.split("_").first}%"
        sql = <<~SQL
          WITH eligible_categories AS (
            #{get.where.not(categories: { locale: nil }).to_sql}
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

        done, total = DB.query_single(sql, base_locale:)
        { done:, total: }
      end
    end
  end
end
