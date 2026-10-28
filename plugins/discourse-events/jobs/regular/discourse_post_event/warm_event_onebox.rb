# frozen_string_literal: true

module Jobs
  # Warms the cached onebox of one of an event's links so the event card can embed
  # it, skipping links the event no longer has by the time the job runs.
  class WarmEventOnebox < ::Jobs::Base
    def execute(args)
      url = args[:url]
      return if url.blank?

      event = DiscourseEvents::Events::Event.find_by(id: args[:event_id])
      return if event.blank? || link(event) != url
      event.warm_onebox!(url)
    end

    private

    def link(event)
      raise NotImplementedError
    end
  end
end
