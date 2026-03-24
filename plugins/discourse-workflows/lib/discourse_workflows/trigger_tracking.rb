# frozen_string_literal: true

module DiscourseWorkflows
  module TriggerTracking
    def triggered_this_minute?(now = Time.current.utc)
      last_triggered = last_triggered_at
      return false unless last_triggered
      last_triggered.beginning_of_minute == now.beginning_of_minute
    end

    def mark_triggered!(now = Time.current.utc)
      update!(static_data: static_data.merge("last_triggered_at" => now.iso8601))
    end

    def triggered_topic_ids
      static_data.fetch("triggered_topic_ids", [])
    end

    def track_triggered_topics!(topic_ids)
      return if topic_ids.blank?
      reload
      update!(
        static_data:
          static_data.merge("triggered_topic_ids" => (triggered_topic_ids + topic_ids).uniq),
      )
    end

    private

    def last_triggered_at
      raw = static_data["last_triggered_at"]
      Time.parse(raw) if raw
    end
  end
end
