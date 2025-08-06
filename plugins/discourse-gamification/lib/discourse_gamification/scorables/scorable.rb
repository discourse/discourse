# frozen_string_literal: true
module ::DiscourseGamification
  class Scorable
    class << self
      def enabled?
        score_multiplier > 0
      end

      def scorable_category_list
        SiteSetting.scorable_categories.split("|").map { _1.to_i }.join(", ")
      end
    end
  end
end
