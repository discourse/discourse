# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseCalendar
      class UpcomingEvents < PageObjects::Pages::Base
        def visit
          super("/upcoming-events")
        end

        def open_year_list
          find(".fc-listYear-button").click
        end

        def open_mine_events
          find(".fc-mineEvents-button").click
        end
      end
    end
  end
end
