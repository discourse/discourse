# frozen_string_literal: true

module PageObjects
  module Modals
    # Methods for when the enable_new_reordering_controls upcoming change is
    # enabled, where the columns are a reorderable list.
    class EditUserDirectoryColumns < PageObjects::Modals::Base
      MODAL_SELECTOR = ".edit-user-directory-columns-modal"
      COLUMN_SELECTOR = "#{MODAL_SELECTOR} .edit-directory-column"

      def open
        find(".open-edit-columns-btn").click
        self
      end

      def move_to_top(column)
        PageObjects::Components::ReorderableList.new(column_selector(column)).move(:top)
        self
      end

      def save
        click_primary_button
        self
      end

      def has_columns_in_order?(columns)
        has_css?(COLUMN_SELECTOR, count: columns.size) &&
          columns.each_with_index.all? do |column, index|
            has_css?(
              "#{COLUMN_SELECTOR}:nth-child(#{index + 1})[data-reorderable-key='#{column.id}']",
            )
          end
      end

      private

      def column_selector(column)
        "#{COLUMN_SELECTOR}[data-reorderable-key='#{column.id}']"
      end
    end
  end
end
