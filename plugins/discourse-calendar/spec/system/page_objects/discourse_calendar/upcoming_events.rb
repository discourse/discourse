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
          expect(page).to have_css(".fc-listYear-view")
          wait_for_timeout
        end

        def open_day_view
          find(".fc-timeGridDay-button").click
          expect(page).to have_css(".fc-timeGridDay-view")
          wait_for_timeout
        end

        def open_week_view
          find(".fc-timeGridWeek-button").click
          expect(page).to have_css(".fc-timeGridWeek-view")
          wait_for_timeout
        end

        def open_month_view
          find(".fc-dayGridMonth-button").click
          expect(page).to have_css(".fc-dayGridMonth-view")
          wait_for_timeout
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

        def find_event_by_title(title)
          find(".fc-event", text: title)
        end

        def has_event_with_time?(title, time)
          event = find_event_by_title(title)
          event.has_css?(".fc-list-event-time", text: time)
        end

        def get_event_height(title)
          find_event_by_title(title).native.bounding_box["height"]
        end

        def find_all_events_by_title(title)
          all(".fc-event", text: title)
        end

        def has_event_height?(title, expected_height)
          height = get_event_height(title)
          height >= expected_height - 1 && height <= expected_height + 1
        end

        def first_weekday_header_text
          find(".fc-col-header .fc-col-header-cell:nth-child(1) .fc-col-header-cell-cushion").text
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
