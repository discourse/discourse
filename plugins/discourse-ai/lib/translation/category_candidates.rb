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
        done = get.where(locale:).count
        done += CategoryLocalization.where(locale:).count

        total = get.count

        done / total.to_f
      end
    end
  end
end
