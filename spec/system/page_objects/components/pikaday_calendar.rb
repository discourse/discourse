# frozen_string_literal: true

module PageObjects
  module Components
    class PikadayCalendar < PageObjects::Components::Base
      attr_reader :context

      def initialize(context)
        @context = context
      end

      def component
        browser_root.locator(@context).filter(visible: true)
      end

      def open_calendar
        component.click
      end

      def visible_pikaday
        browser_root.locator(".pika-single:not(.is-hidden)").filter(visible: true)
      end

      def hidden?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".pika-single:not(.is-hidden)").filter(visible: true),
        )
      end

      def select_date(year, month, day)
        open_calendar
        select_year(year)
        select_month(month)
        select_day(day)
      end

      def select_day(day_number)
        browser_root
          .locator("button.pika-button.pika-day[data-pika-day='#{day_number}']:not(.is-disabled)")
          .filter(visible: true)
          .click
      end

      # The month is 0-based. Month name can be provided too.
      def select_month(month)
        parsed_month =
          begin
            Integer(month)
          rescue StandardError
            nil
          end

        if parsed_month.nil?
          parsed_month =
            {
              "january" => 0,
              "february" => 1,
              "march" => 2,
              "april" => 3,
              "may" => 4,
              "june" => 5,
              "july" => 6,
              "august" => 7,
              "september" => 8,
              "october" => 9,
              "november" => 10,
              "december" => 11,
            }[
              month.downcase
            ]
        end

        # visible: false is here because pikaday sets the controls
        # to opacity: 0 for some reason.
        visible_pikaday
          .locator(".pika-select-month")
          .click
          .locator("option[value='#{parsed_month}']")
          .filter(visible: true)
          .click
      end

      def select_year(year)
        # need to wait for the element since eval_on_selector doesn't
        browser_root.locator(".pika-select-year")

        browser_page.then do |playwright_page|
          playwright_page.eval_on_selector(
            ".pika-select-year",
            "select => { select.value = '#{year}'; select.dispatchEvent(new Event('change', { bubbles: true })); }",
          )
        end
      end
    end
  end
end
