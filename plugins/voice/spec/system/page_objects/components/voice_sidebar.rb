# frozen_string_literal: true

module PageObjects
  module Components
    class VoiceSidebar < PageObjects::Components::Base
      ROOM_LINK_SELECTOR = ".sidebar-section-link.voice-sidebar-link"

      attr_reader :section_selector

      def initialize(section_name: "voice-rooms")
        @section_selector = ".sidebar-section[data-section-name='#{section_name}']"
      end

      def visible?
        page.has_css?(section_selector)
      end

      def not_visible?
        page.has_no_css?(section_selector)
      end

      def has_room?(room_name)
        page.has_css?(section_selector, text: room_name)
      end

      def has_no_room?(room_name)
        page.has_no_css?(section_selector, text: room_name)
      end

      def room_link(room_id)
        find("#{ROOM_LINK_SELECTOR}[data-link-name='voice-room-#{room_id}']")
      end

      def has_room_link?(room_id)
        page.has_css?("#{ROOM_LINK_SELECTOR}[data-link-name='voice-room-#{room_id}']")
      end

      def has_no_room_link?(room_id)
        page.has_no_css?("#{ROOM_LINK_SELECTOR}[data-link-name='voice-room-#{room_id}']")
      end

      def click_room(room_id)
        room_link(room_id).click
        self
      end

      def has_active_room?(room_id)
        page.has_css?(
          "#{ROOM_LINK_SELECTOR}[data-link-name='voice-room-#{room_id}'].sidebar-section-link--active",
        )
      end

      def has_no_active_room?(room_id)
        page.has_no_css?(
          "#{ROOM_LINK_SELECTOR}[data-link-name='voice-room-#{room_id}'].sidebar-section-link--active",
        )
      end

      def has_participants?(room_id)
        page.has_css?(
          "#{ROOM_LINK_SELECTOR}[data-link-name='voice-room-#{room_id}'] .voice-sidebar-link__participants",
        )
      end

      def has_no_participants?(room_id)
        page.has_no_css?(
          "#{ROOM_LINK_SELECTOR}[data-link-name='voice-room-#{room_id}'] .voice-sidebar-link__participants",
        )
      end

      def has_speaking_indicator?(room_id)
        page.has_css?(
          "#{ROOM_LINK_SELECTOR}[data-link-name='voice-room-#{room_id}'] .voice-sidebar-link__avatar--speaking",
        )
      end

      def section_title
        find("#{section_selector} .sidebar-section-header-text").text
      end
    end
  end
end
