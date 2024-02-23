# frozen_string_literal: true

module Jobs
  class UpdateTopicHotScores < ::Jobs::Scheduled
    every 10.minutes

    HOT_SCORE_DAILY_KEY = "hot_score_daily"

    def execute(args)
      if SiteSetting.top_menu_map.include?("hot") ||
           Discourse.redis.set(HOT_SCORE_DAILY_KEY, 1, ex: 6.hour, nx: true)
        TopicHotScore.update_scores
      end
    end

    def self.clear_once_a_day_cache!
      Discourse.redis.del(HOT_SCORE_DAILY_KEY)
    end
  end
end
