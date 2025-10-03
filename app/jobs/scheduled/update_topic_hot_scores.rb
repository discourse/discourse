# frozen_string_literal: true

module Jobs
  class UpdateTopicHotScores < ::Jobs::Scheduled
    every 10.minutes

    HOT_SCORE_UPDATE_REDIS_KEY = "hot_score_6_hourly"

    def execute(args)
      if SiteSetting.top_menu_map.include?("hot") ||
           Discourse.redis.set(HOT_SCORE_UPDATE_REDIS_KEY, 1, ex: 6.hour, nx: true)
        TopicHotScore.update_scores
      end
    end
  end
end
