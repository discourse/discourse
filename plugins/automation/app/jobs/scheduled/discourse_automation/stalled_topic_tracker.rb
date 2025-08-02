# frozen_string_literal: true

module Jobs
  class DiscourseAutomation::StalledTopicTracker < ::Jobs::Scheduled
    every 1.hour

    def execute(_args = nil)
      name = ::DiscourseAutomation::Triggers::STALLED_TOPIC

      ::DiscourseAutomation::Automation
        .where(trigger: name, enabled: true)
        .find_each do |automation|
          fields = automation.serialized_fields
          stalled_after = fields.dig("stalled_after", "value")
          stalled_duration = ISO8601::Duration.new(stalled_after).to_seconds
          stalled_date = stalled_duration.seconds.ago
          categories = fields.dig("categories", "value")
          tags = fields.dig("tags", "value")

          ::DiscourseAutomation::StalledTopicFinder
            .call(stalled_date, categories: categories, tags: tags)
            .each do |result|
              topic = Topic.find_by(id: result.id)
              next unless topic

              run_trigger(automation, topic)
            end
        end
    end

    def run_trigger(automation, topic)
      automation.trigger!(
        "kind" => ::DiscourseAutomation::Triggers::STALLED_TOPIC,
        "topic" => topic,
        "placeholders" => {
          "topic_url" => topic.url,
        },
      )
    end
  end
end
