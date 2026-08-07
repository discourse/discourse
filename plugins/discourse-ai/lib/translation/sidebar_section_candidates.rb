# frozen_string_literal: true

module DiscourseAi
  module Translation
    class SidebarSectionCandidates < BaseCandidates
      private

      def self.get
        SidebarSection.public_sections.custom_sections
      end

      def self.calculate_completion_per_locale(locale)
        base_locale = "#{locale.split("_").first}%"
        sql = <<~SQL
          WITH eligible_sidebar_sections AS (
            #{get.where.not(sidebar_sections: { locale: nil }).to_sql}
          ),
          total_count AS (
            SELECT COUNT(*) AS count FROM eligible_sidebar_sections
          ),
          done_count AS (
            SELECT COUNT(DISTINCT ss.id)
            FROM eligible_sidebar_sections ss
            LEFT JOIN sidebar_section_localizations ssl
              ON ss.id = ssl.sidebar_section_id AND ssl.locale LIKE :base_locale
            WHERE ss.locale LIKE :base_locale OR ssl.sidebar_section_id IS NOT NULL
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
