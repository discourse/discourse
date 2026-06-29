# frozen_string_literal: true

module Jobs
  # Warms the cached onebox for a livestream event's URL so the event card can
  # render the embedded (lazy) video from EventSerializer#livestream_onebox.
  class WarmLivestreamOnebox < ::Jobs::Base
    def execute(args)
      url = args[:url]
      return if url.blank?

      Oneboxer.onebox(url)

      event = DiscoursePostEvent::Event.find_by(id: args[:event_id])
      return if event.blank? || !event.livestream? || event.location != url

      event.post&.publish_change_to_clients!(:revised)
    end
  end
end
