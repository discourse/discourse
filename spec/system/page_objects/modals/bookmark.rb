# frozen_string_literal: true

module PageObjects
  module Modals
    class Bookmark < PageObjects::Modals::Base
      def fill_name(name)
        fill_in("bookmark-name", with: name)
      end

      def name
        find("#bookmark-name")
      end

      def select_preset_reminder(identifier)
        find("#tap_tile_#{identifier}").click
      end

      def has_active_preset?(identifier)
        has_css?("#tap_tile_#{identifier}.tap-tile.active")
      end

      def has_preset?(identifier)
        has_css?("#tap_tile_#{identifier}")
      end

      def has_no_preset?(identifier)
        has_no_css?("#tap_tile_#{identifier}")
      end

      def editing_id?(bookmark_id)
        has_css?(".bookmark-reminder-modal[data-bookmark-id='#{bookmark_id}']")
      end

      def open_options_panel
        find(".bookmark-options-button").click
      end

      def has_open_options_panel?
        has_css?(".bookmark-options-panel")
      end

      def select_auto_delete_preference(preference)
        select_kit = PageObjects::Components::SelectKit.new("#bookmark-auto-delete-preference")
        select_kit.expand
        select_kit.select_row_by_value(preference)
      end

      def has_auto_delete_preference?(preference)
        select_kit = PageObjects::Components::SelectKit.new("#bookmark-auto-delete-preference")
        select_kit.has_selected_value?(preference)
      end

      def custom_date_picker
        find(".tap-tile-date-input #custom-date .date-picker")
      end

      def custom_time_picker
        find(".tap-tile-time-input #custom-time")
      end

      def save
        find("#save-bookmark").click
      end

      def delete
        find("#delete-bookmark").click
      end

      def confirm_delete
        find(".dialog-footer .btn-danger").click
      end

      def existing_reminder_alert
        find(".existing-reminder-at-alert")
      end

      def existing_reminder_alert_message(bookmark)
        I18n.t(
          "js.bookmarks.reminders.existing_reminder",
          at_date_time:
            I18n.t(
              "js.bookmarks.reminders.at_time",
              date_time:
                bookmark
                  .reminder_at_in_zone(bookmark.user.user_option&.timezone || "UTC")
                  .strftime("%b %-d, %Y %l:%M %P")
                  .gsub("  ", " "), # have to do this because %l adds padding before the hour but not in JS
            ),
        )
      end
    end
  end
end
