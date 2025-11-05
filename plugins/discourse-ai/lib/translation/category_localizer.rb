# frozen_string_literal: true

module DiscourseAi
  module Translation
    class CategoryLocalizer
      def self.localize(category, target_locale = I18n.locale)
        return if category.blank? || target_locale.blank?

        target_locale = target_locale.to_s.sub("-", "_")

        translated_name = ShortTextTranslator.new(text: category.name, target_locale:).translate
        translated_description =
          if category.description_excerpt.present?
            PostRawTranslator.new(text: category.description_excerpt, target_locale:).translate
          else
            ""
          end

        localization =
          CategoryLocalization.find_or_initialize_by(
            category_id: category.id,
            locale: target_locale,
          )

        localization.name = translated_name
        localization.description = translated_description
        localization.save!
        localization
      end

      # Checks if a category has remaining quota for re-localization attempts.
      # Uses atomic Redis INCR to prevent race conditions.
      # The quota key expires after 24 hours, allowing retries after that period.
      #
      # @param category_id [Integer] The category ID
      # @param locale [String] The target locale
      # @return [Boolean] true if quota is available (attempts <= 2), false if exhausted
      def self.has_relocalize_quota?(category_id, locale)
        key = relocalize_key(category_id, locale)
        count = Discourse.redis.incr(key)
        # Only set expiry on first increment to avoid resetting the TTL on subsequent checks
        Discourse.redis.expire(key, 1.day.to_i) if count == 1
        count <= 2
      end

      private

      def self.relocalize_key(category_id, locale)
        "category_relocalized_#{category_id}_#{locale}"
      end
    end
  end
end
