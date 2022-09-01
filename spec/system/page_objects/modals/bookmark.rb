# frozen_string_literal: true

module PageObjects
  module Modals
    class Bookmark < PageObjects::Modals::Base
      def fill_name(name)
        fill_in "bookmark-name", with: name
      end

      def select_preset_reminder(identifier)
        find("#tap_tile_#{identifier}").click
      end

      def save
        find("#save-bookmark").click
      end
    end
  end
end
