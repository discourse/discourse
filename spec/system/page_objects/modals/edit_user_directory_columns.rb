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

      def drag_after_with_touch(column, target)
        grip = find("#{column_selector(column)} .d-reorderable-list__handle").native.bounding_box
        row = find(column_selector(target)).native.bounding_box
        x = grip["x"] + grip["width"] / 2
        start_y = grip["y"] + grip["height"] / 2
        end_y = row["y"] + row["height"] * 0.75

        page.driver.with_playwright_page do |browser_page|
          session = browser_page.context.new_cdp_session(browser_page)
          dispatch_touch(session, "touchStart", [{ x:, y: start_y }])
          dispatch_touch(session, "touchMove", [{ x:, y: end_y }])
          yield if block_given?
        ensure
          dispatch_touch(session, "touchEnd", []) if session
          session&.detach
        end
        self
      end

      def save
        click_primary_button
        self
      end

      def has_touch_drag_feedback?(column, after:)
        has_css?("#{column_selector(column)}.--touch-dragging") &&
          has_css?("#{column_selector(after)}.--drag-below")
      end

      def has_no_touch_drag_feedback?
        has_no_css?("#{COLUMN_SELECTOR}:is(.--touch-dragging, .--drag-below, .--drag-above)")
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

      def dispatch_touch(session, type, points)
        session.send_message("Input.dispatchTouchEvent", params: { type:, touchPoints: points })
      end

      def column_selector(column)
        "#{COLUMN_SELECTOR}[data-reorderable-key='#{column.id}']"
      end
    end
  end
end
