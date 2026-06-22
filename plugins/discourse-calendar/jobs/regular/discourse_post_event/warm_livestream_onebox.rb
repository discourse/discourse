# frozen_string_literal: true

module Jobs
  # Warms the cached onebox for a livestream event's URL so the event card can
  # render the embedded (lazy) video from EventSerializer#livestream_onebox.
  class WarmLivestreamOnebox < ::Jobs::Base
    def execute(args)
      url = args[:url]
      Oneboxer.onebox(url) if url.present?
    end
  end
end
