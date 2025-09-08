# frozen_string_literal: true

module DiscourseAi
  module Translation
    class BaseCandidates
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
      def self.get_completion_per_locale(locale)
        Discourse
          .cache
          .fetch(get_completion_cache_key(locale), expires_in: CACHE_TTL) do
            done, total = calculate_completion_per_locale(locale)
            return { done: 0, total: 0 } if total.zero?
            { done:, total: }
          end
      end

      def self.clear_completion_cache(locale)
        Discourse.cache.delete(get_completion_cache_key(locale))
      end

      private

      # ModelType that are eligible for translation based on site settings
      # @return [ActiveRecord::Relation] the ActiveRecord relation of the candidates
      def self.get
        raise NotImplementedError
      end

      # This method should return [completed_translations, total_needed_translations]
      #
      # This allows flexibility for the implementation to determine how the completion percentage is calculated.
      # # @param locale [String] the locale for which to calculate the completion percentage
      # @return [integer, integer] the number of done and total translations for the given locale
      def self.calculate_completion_per_locale(locale)
        raise NotImplementedError
      end

      def self.completion_cache_key_for_type
        raise NotImplementedError
      end

      def self.total_cache_key_for_type
        raise NotImplementedError
      end

      def self.get_completion_cache_key(locale)
        "#{cache_key_for_type}_completion_#{locale}"
      end

      def self.get_total_cache_key
        "#{cache_key_for_type}_total"
      end

      def self.total_and_with_locale_count
        DB.query_single(<<~SQL)
          WITH eligible_posts AS (
            #{get.to_sql}
          ),
          total_count AS (
            SELECT COUNT(*) AS count FROM eligible_posts
          ),
          done_count AS (
            SELECT COUNT(DISTINCT p.id)
            FROM eligible_posts p
            WHERE p.locale IS NOT NULL
          )
          SELECT t.count AS total, d.count AS done
          FROM total_count t, done_count d
        SQL
      end
    end
  end
end
