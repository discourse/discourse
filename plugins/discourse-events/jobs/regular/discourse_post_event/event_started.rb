# frozen_string_literal: true

module Jobs
  class DiscoursePostEventEventStarted < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      raise Discourse::InvalidParameters.new(:event_id) if args[:event_id].blank?
      event = DiscoursePostEvent::Event.find(args[:event_id])
      MessageBus.publish("/topic/#{event.post.topic_id}", reload_topic: true, refresh_stream: true)
      DiscourseEvent.trigger(:discourse_post_event_event_started, event)
    end
  end
end
