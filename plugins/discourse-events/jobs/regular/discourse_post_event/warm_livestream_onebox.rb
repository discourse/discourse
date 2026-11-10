# frozen_string_literal: true

module Jobs
  # Feeds EventSerializer#livestream_onebox.
  class WarmLivestreamOnebox < WarmEventOnebox
    private

    def link(event)
      event.livestream_url if event.livestream?
    end
  end
end
