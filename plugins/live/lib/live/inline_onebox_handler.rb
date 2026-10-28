# frozen_string_literal: true

module Live
  class InlineOneboxHandler
    def self.handle(url, route)
      return unless room = Live::OneboxHandler.oneboxable_room(route)

      # Inline oneboxes carry text only, so live-onebox.scss draws the room
      # icon from this class. It must stay a single class: the composer
      # preview applies it with classList.add, which rejects spaces.
      {
        url: url,
        title: I18n.t("live.onebox.inline_to_room", room_name: room.name),
        css_class: room.stage? ? "live-inline-onebox-stage" : "live-inline-onebox-room",
      }
    end
  end
end
