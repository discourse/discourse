# frozen_string_literal: true

module DiscourseAi
  module Translation
    class BaseCandidates
      CACHE_TTL = 1.hour

      private

      # ModelType that are eligible for translation based on site settings
      # @return [ActiveRecord::Relation] the ActiveRecord relation of the candidates
      def self.get
        raise NotImplementedError
      end

      def self.total_and_with_locale_count
        DB.query_single(<<~SQL)
          WITH eligible AS (
            #{get.to_sql}
          ),
          total_count AS (
            SELECT COUNT(*) AS count FROM eligible
          ),
          done_count AS (
            SELECT COUNT(DISTINCT e.id)
            FROM eligible e
            WHERE e.locale IS NOT NULL
          )
          SELECT t.count AS total, d.count AS done
          FROM total_count t, done_count d
        SQL
      end
    end
  end
end
