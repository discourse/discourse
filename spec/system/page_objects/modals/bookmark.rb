# frozen_string_literal: true

module PageObjects
  module Modals
    class Bookmark < PageObjects::Modals::Base
      def fill_name(name)
        browser_root
          .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
          .and(
            browser_root.locator(
              "[id=#{"bookmark-name".to_s.to_json}], [name=#{"bookmark-name".to_s.to_json}]",
            ).or(browser_root.get_by_label("bookmark-name", exact: true)),
          )
          .filter(visible: true)
          .fill(name)
      end

      def name
        browser_root.locator("#bookmark-name").filter(visible: true)
      end

      def select_preset_reminder(identifier)
        browser_root.locator("#tap_tile_#{identifier}").filter(visible: true).click
        closed?
      end

      def has_active_preset?(identifier)
        have_count(0).does_not_match?(
          browser_root.locator("#tap_tile_#{identifier}.tap-tile.active").filter(visible: true),
        )
      end

      def has_preset?(identifier)
        have_count(0).does_not_match?(
          browser_root.locator("#tap_tile_#{identifier}").filter(visible: true),
        )
      end

      def has_no_preset?(identifier)
        have_count(0).matches?(
          browser_root.locator("#tap_tile_#{identifier}").filter(visible: true),
        )
      end

      def editing_id?(bookmark_id)
        have_count(0).does_not_match?(
          browser_root.locator(
            ".bookmark-reminder-modal[data-bookmark-id='#{bookmark_id}']",
          ).filter(visible: true),
        )
      end

      def select_relative_time_duration(duration)
        browser_root
          .locator("#bookmark-relative-time-picker input")
          .filter(visible: true)
          .fill(duration.to_s)
      end

      def select_relative_time_interval(interval)
        select_kit = PageObjects::Components::SelectKit.new(".relative-time-intervals")
        select_kit.expand
        select_kit.select_row_by_value(interval)
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
        browser_root.locator(".tap-tile-date-input #custom-date .date-picker").filter(visible: true)
      end

      def custom_time_picker
        browser_root.locator(".tap-tile-time-input #custom-time").filter(visible: true)
      end

      def save
        browser_root.locator("#save-bookmark").filter(visible: true).click
      end

      def delete
        browser_root.locator("#delete-bookmark").filter(visible: true).click
      end

      def confirm_delete
        browser_root.locator(".dialog-footer .btn-danger").filter(visible: true).click
      end

      def existing_reminder_alert
        browser_root.locator(".existing-reminder-at-alert").filter(visible: true)
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
