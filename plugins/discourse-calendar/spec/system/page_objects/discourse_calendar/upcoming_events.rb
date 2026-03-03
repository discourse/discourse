# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseCalendar
      class UpcomingEvents < PageObjects::Pages::Base
        def visit
          super("/upcoming-events")
          self
        end

        def next
          find(".fc-next-button").click
          self
        end

        def prev
          find(".fc-prev-button").click
          self
        end

        def today
          find(".fc-today-button").click
          self
        end

        def open_year_view
          find(".fc-listYear-button").click
          has_css?(".fc-listYear-view", wait: 5)
          self
        end

        def open_day_view
          find(".fc-timeGridDay-button").click
          has_css?(".fc-timeGridDay-view", wait: 5)
          self
        end

        def open_week_view
          find(".fc-timeGridWeek-button").click
          has_css?(".fc-timeGridWeek-view", wait: 5)
          self
        end

        def open_month_view
          find(".fc-dayGridMonth-button").click
          has_css?(".fc-dayGridMonth-view", wait: 5)
          self
        end

        def open_mine_events
          find(".fc-mineEvents-button").click
          self
        end

        def open_all_events
          find(".fc-allEvents-button").click
          self
        end

        def click_event(title)
          find("a", text: title).click
          self
        end

        def click_recurring_event(occurrence:, title: nil)
          row = occurrence * 2
          selector = "tr.fc-list-event:nth-child(#{row}) .fc-list-event-title a"
          if title
            find(selector, text: title).click
          else
            find(selector).click
          end
          self
        end

        def close_event_modal
          page.send_keys(:escape)
          self
        end

        def has_calendar?
          has_css?("#upcoming-events-calendar .fc")
        end

        def has_event?(title)
          has_css?(".fc-event-title", text: title)
        end

        def has_no_event?(title)
          has_no_css?(".fc-event-title", text: title)
        end

        def has_event_count?(count)
          has_css?(".fc-daygrid-event-harness", count:)
        end

        def has_content_in_calendar?(text)
          has_css?("#upcoming-events-calendar .fc", text:)
        end

        def has_current_path?(path)
          page.has_current_path?(path)
        end

        def has_content?(text)
          page.has_content?(text)
        end

        def has_event_with_time?(title, time)
          has_css?(".fc-event", text: title) &&
            find(".fc-event", text: title).has_css?(".fc-list-event-time", text: time)
        end

        def has_event_dates?(text)
          has_css?(".event__section.event-dates", text:)
        end

        def has_recurring_event_time?(occurrence:, time:)
          # occurrence 1 = nth-child(2), occurrence 2 = nth-child(4), etc.
          row = occurrence * 2
          has_css?("tr.fc-list-event:nth-child(#{row}) .fc-list-event-time", text: time)
        end

        def has_event_height?(title, expected_height)
          height = find(".fc-event", text: title).native.bounding_box["height"]
          height >= expected_height - 1 && height <= expected_height + 1
        end

        def has_block_event_style?
          has_css?(".fc-daygrid-block-event")
        end

        def has_dot_event_style?
          has_css?(".fc-daygrid-dot-event")
        end

        def has_event_dot_color?(color)
          has_css?(".fc-daygrid-event-dot") &&
            get_rgb_color(find(".fc-daygrid-event-dot"), "borderColor") == color
        end

        def has_first_column_as_sunday?
          has_css?(".fc-daygrid-body tr td:nth-child(1).fc-day-sun", minimum: 1)
        end

        def has_first_column_as_saturday?
          has_css?(".fc-daygrid-body tr td:nth-child(1).fc-day-sat", minimum: 1)
        end

        def has_first_column_as_monday?
          has_css?(".fc-daygrid-body tr td:nth-child(1).fc-day-mon", minimum: 1)
        end
      end
    end
  end
end
