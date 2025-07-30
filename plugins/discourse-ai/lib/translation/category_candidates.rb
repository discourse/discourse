# frozen_string_literal: true

module DiscourseAi
  module Translation
    class CategoryCandidates
      def self.get
        categories = Category.all
        if SiteSetting.ai_translation_backfill_limit_to_public_content
          categories = categories.where(read_restricted: false)
        end
        categories
      end

      def self.get_completion_per_locale(locale)
        total = get.count
        return 1.0 if total.zero?

        base_locale = "#{locale.split("_").first}%"
        sql = <<~SQL
          WITH eligible_categories AS (
            #{get.to_sql}
          )
          SELECT COUNT(DISTINCT c.id)
          FROM eligible_categories c
          LEFT JOIN category_localizations cl ON c.id = cl.category_id AND cl.locale LIKE :base_locale
          WHERE c.locale LIKE :base_locale OR cl.category_id IS NOT NULL
        SQL

        done = DB.query_single(sql, base_locale:).first.to_i || 0
        done / total.to_f
      end
    end
  end
end
