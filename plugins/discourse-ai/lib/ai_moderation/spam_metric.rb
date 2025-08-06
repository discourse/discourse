# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    class SpamMetric
      def self.update(new_status, reviewable)
        return if !defined?(::DiscoursePrometheus)
        ai_spam_log = AiSpamLog.find_by(reviewable:)
        return if ai_spam_log.nil?

        increment("scanned")
        increment("is_spam") if new_status == :approved && ai_spam_log.is_spam
        increment("false_positive") if new_status == :rejected && ai_spam_log.is_spam
        increment("false_negative") if new_status == :rejected && !ai_spam_log.is_spam
      end

      private

      def self.increment(type, value = 1)
        metric = ::DiscoursePrometheus::InternalMetric::Custom.new
        metric.name = "discourse_ai_spam_detection"
        metric.type = "Counter"
        metric.description = "AI spam scanning statistics"
        metric.labels = { db: RailsMultisite::ConnectionManagement.current_db, type: }
        metric.value = value
        $prometheus_client.send_json(metric.to_h) # rubocop:disable Style/GlobalVars
      end
    end
  end
end
