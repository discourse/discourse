# frozen_string_literal: true
module DiscourseGamification
  class Scorable
    class << self
      def enabled?(leaderboard: nil)
        return false if category_scoped?(leaderboard:) && !supports_category_scoping?

        score_multiplier(leaderboard:) > 0
      end

      def supports_category_scoping?
        false
      end

      def category_scoped?(leaderboard:)
        Array(leaderboard&.scorable_category_ids).compact.present?
      end

      def scorable_key
        name.demodulize.underscore
      end

      def score_multiplier(leaderboard: nil)
        override = leaderboard&.score_override_for(scorable_key)
        return override unless override.nil?
        SiteSetting.public_send(:"#{scorable_key}_score_value")
      end

      def scorable_category_list(leaderboard: nil)
        scorable_category_ids(leaderboard:).join(", ")
      end

      def scorable_category_ids(leaderboard: nil)
        categories = leaderboard&.scorable_category_ids
        if categories.nil?
          SiteSetting.scorable_categories.split("|").map { it.to_i }
        else
          categories.compact
        end
      end
    end
  end
end
