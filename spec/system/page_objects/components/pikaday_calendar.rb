# frozen_string_literal: true

module PageObjects
  module Components
    class PikadayCalendar < PageObjects::Components::Base
      attr_reader :context

      def initialize(context)
        @context = context
      end

      def component
        find(@context)
      end

      def open_calendar
        component.click
      end

      def visible_pikaday
        find(".pika-single:not(.is-hidden)")
      end

      def hidden?
        page.has_no_css?(".pika-single:not(.is-hidden)")
      end

      def select_date(year, month, day)
        open_calendar
        select_year(year)
        select_month(month)
        select_day(day)
      end

      def select_day(day_number)
        find("button.pika-button.pika-day[data-pika-day='#{day_number}']:not(.is-disabled)").click
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
          .find(".pika-select-month", visible: false)
          .click
          .find("option[value='#{parsed_month}']")
          .click
      end

      def select_year(year)
        # visible: false is here because pikaday sets the controls
        # to opacity: 0 for some reason.
        select_element = visible_pikaday.find(".pika-select-year", visible: false)
        page.driver.with_playwright_page do |playwright_page|
          playwright_page.eval_on_selector(
            ".pika-select-year",
            "select => { select.value = '#{year}'; select.dispatchEvent(new Event('change', { bubbles: true })); }",
          )
        end
      end
    end
  end
end
