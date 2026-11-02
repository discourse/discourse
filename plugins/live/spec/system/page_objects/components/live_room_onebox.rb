# frozen_string_literal: true

module PageObjects
  module Components
    class LiveRoomOnebox < PageObjects::Components::Base
      SELECTOR = "aside.onebox.live-room-onebox"

      def initialize(room)
        @room = room
      end

      def card
        find("#{SELECTOR}:has(a[href$='/live/r/#{@room.slug}'])")
      end

      def has_name?(name)
        card.has_css?(".live-room-onebox__name", text: name)
      end

      def has_type?(label)
        card.has_css?(".live-room-onebox__type", text: label)
      end

      def has_presence?(count:)
        card.has_css?(
          ".live-room-onebox__presence",
          text: I18n.t("js.live.onebox.here_now", count:),
        ) && card.has_css?(".live-room-onebox__presence-avatars .avatar", count: [count, 5].min)
      end

      def has_no_presence?
        card.has_no_css?(".live-room-onebox__presence")
      end
    end
  end
end
