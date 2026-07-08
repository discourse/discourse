# frozen_string_literal: true

module Jobs
  # Warms the cached onebox for a livestream event's URL so the event card can
  # render the embedded (lazy) video from EventSerializer#livestream_onebox.
  class WarmLivestreamOnebox < ::Jobs::Base
    def execute(args)
      url = args[:url]
      return if url.blank?

      event = DiscoursePostEvent::Event.find_by(id: args[:event_id])
      return if event.blank? || event.location != url
      event.warm_livestream_onebox!(publish: true)
    end
  end
end
