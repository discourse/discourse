# frozen_string_literal: true

class TopicViewStatsQuery
  MAX_STATS = 300

  def self.call(topic:, guardian:, from:, to:)
    guardian.ensure_can_see!(topic)

    TopicViewStat
      .where(topic_id: topic.id, viewed_at: from..to)
      .order(viewed_at: :desc)
      .limit(MAX_STATS)
      .reverse
  end
end
