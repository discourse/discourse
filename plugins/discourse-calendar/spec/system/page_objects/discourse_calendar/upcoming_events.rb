# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseCalendar
      class UpcomingEvents < PageObjects::Pages::Base
        def visit
          super("/upcoming-events")
        end

        def next
          find(".fc-next-button").click
        end

        def prev
          find(".fc-prev-button").click
        end

        def today
          find(".fc-today-button").click
        end

        def open_year_view
          find(".fc-listYear-button").click
        end

        def open_day_view
          find(".fc-timeGridDay-button").click
        end

        def open_week_view
          find(".fc-timeGridWeek-button").click
        end

        def open_month_view
          find(".fc-dayGridMonth-button").click
        end

        def open_mine_events
          find(".fc-mineEvents-button").click
        end

        def open_all_events
          find(".fc-allEvents-button").click
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
          has_css?(".fc-daygrid-event-harness", count: count)
        end

        def has_content_in_calendar?(text)
          has_css?("#upcoming-events-calendar .fc", text: text)
        end

        def has_event_at_position?(title, row:, col:)
          has_css?(".fc tr:nth-child(#{row}) td:nth-child(#{col}) .fc-event-title", text: title)
        end

        def find_event_by_position(position)
          find(".fc-event:nth-child(#{position})")
        end

        def event_time_text(event_element)
          event_element.find(".fc-list-event-time").text
        end

        def event_title_text(event_element)
          event_element.find(".fc-list-event-title").text
        end

        def current_view_title
          find(".fc-toolbar-title").text
        end

        def has_current_path?(path)
          page.has_current_path?(path)
        end

        def has_content?(text)
          page.has_content?(text)
        end

        def expect_to_be_on_path(path)
          expect(self).to have_current_path(path)
        end

        def expect_content(text)
          expect(self).to have_content(text)
        end

        def expect_event_visible(title)
          expect(self).to have_event(title)
        end

        def expect_event_not_visible(title)
          expect(self).to have_no_event(title)
        end

        def expect_event_count(count)
          expect(self).to have_event_count(count)
        end

        def expect_event_at_position(title, row:, col:)
          expect(self).to have_event_at_position(title, row: row, col: col)
        end
      end
    end
  end
end
