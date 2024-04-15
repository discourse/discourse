# frozen_string_literal: true

module Jobs
  class StreamTopicSummary < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless topic = Topic.find_by(id: args[:topic_id])
      return unless user = User.find_by(id: args[:user_id])

      strategy = Summarization::Base.selected_strategy
      return if strategy.nil? || !Summarization::Base.can_see_summary?(topic, user)

      guardian = Guardian.new(user)
      return unless guardian.can_see?(topic)

      opts = args[:opts] || {}

      streamed_summary = +""
      start = Time.now

      summary =
        TopicSummarization
          .new(strategy)
          .summarize(topic, user, opts) do |partial_summary|
            streamed_summary << partial_summary

            # Throttle updates.
            if (Time.now - start > 0.5) || Rails.env.test?
              payload = { done: false, topic_summary: { summarized_text: streamed_summary } }
              publish_update(topic, user, payload)
              start = Time.now
            end
          end

      publish_update(
        topic,
        user,
        TopicSummarySerializer.new(summary, { scope: guardian }).as_json.merge(done: true),
      )
    end

    private

    def publish_update(topic, user, payload)
      MessageBus.publish("/summaries/topic/#{topic.id}", payload, user_ids: [user.id])
    end
  end
end
