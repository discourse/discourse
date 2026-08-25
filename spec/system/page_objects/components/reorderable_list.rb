# frozen_string_literal: true

module PageObjects
  module Components
    # Drives a `DReorderableList` row.
    #
    # A move is two interactions rather than one — open the row's handle menu,
    # then choose a destination — so every surface that reorders would
    # otherwise repeat the pair. Naming the destination also keeps a page
    # object readable when a grouped list adds cross-list entries and the
    # menu's positions shift.
    class ReorderableList < PageObjects::Components::Base
      HANDLE = ".d-reorderable-list__handle"

      # @param row_selector [String] CSS reaching the row to operate on.
      def initialize(row_selector)
        @row_selector = row_selector
      end

      def open_menu
        find("#{@row_selector} #{HANDLE}").click
        self
      end

      # @param target [Symbol, String] :top, :up, :down, :bottom, or :list.
      def move(target)
        open_menu
        find(destination_selector(target)).click
        self
      end

      # A destination the row cannot take is not rendered, so the menu holds
      # only what it can reach and the set it publishes matches it.
      def has_destination?(target)
        open_menu
        result = has_css?(destination_selector(target))
        close_menu
        result
      end

      def has_no_destination?(target)
        open_menu
        result = has_no_css?(destination_selector(target))
        close_menu
        result
      end

      def has_handle?
        has_css?("#{@row_selector} #{HANDLE}")
      end

      private

      def close_menu
        send_keys(:escape)
      end

      def destination_selector(target)
        ".d-reorderable-list__move-item.--#{target}"
      end
    end
  end
end
