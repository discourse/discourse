# frozen_string_literal: true

module PageObjects
  module Modals
    class CreateColorPalette < PageObjects::Pages::Base
      def modal
        find(".create-color-palette")
      end

      def base_dropdown
        PageObjects::Components::SelectKit.new(".select-base-palette")
      end

      def create_button
        within(modal) { find(".btn-primary") }
      end
    end
  end
end
