# frozen_string_literal: true

module Jobs
  # Warms the cached onebox for an event's recording link so the event card can
  # embed it from EventSerializer#recording_onebox.
  class WarmRecordingOnebox < ::Jobs::Base
    def execute(args)
      url = args[:url]
      return if url.blank?

      event = DiscourseEvents::Events::Event.find_by(id: args[:event_id])
      return if event.blank? || event.recording_link != url
      event.warm_recording_onebox!
    end
  end
end
