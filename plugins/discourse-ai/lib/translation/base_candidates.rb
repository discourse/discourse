# frozen_string_literal: true

module DiscourseAi
  module Translation
    class BaseCandidates
      COMPLETION_CACHE_TTL = 1.hour

      # ModelType that are eligible for translation based on site settings
      # @return [ActiveRecord::Relation] the ActiveRecord relation of the candidates
      def self.get
        raise NotImplementedError
      end

      # The completion in float percentage for the given locale
      # @param locale [String] the locale for which to calculate the completion percentage
      # @return [Float] the completion percentage for the given locale e.g. 0.75 for 75%
      def self.get_completion_per_locale(locale)
        Discourse
          .cache
          .fetch(get_completion_cache_key(locale), expires_in: COMPLETION_CACHE_TTL) do
            done, total = calculate_completion_per_locale(locale)
            return 1.0 if total.zero?
            done / total.to_f
          end
      end

      def self.clear_completion_cache(locale)
        Discourse.cache.delete(get_completion_cache_key(locale))
      end

      private

      # This method should return [completed_translations, total_needed_translations]
      #
      # This allows flexibility for the implementation to determine how the completion percentage is calculated.
      # # @param locale [String] the locale for which to calculate the completion percentage
      # @return [integer, integer]
      def self.calculate_completion_per_locale(locale)
        raise NotImplementedError
      end

      def self.completion_cache_key_for_type
        raise NotImplementedError
      end

      def self.get_completion_cache_key(locale)
        "#{completion_cache_key_for_type}_#{locale}"
      end
    end
  end
end
