# frozen_string_literal: true

module Jobs
  # Feeds EventSerializer#recording_onebox.
  class WarmRecordingOnebox < WarmEventOnebox
    private

    def link(event)
      event.recording_link
    end
  end
end
