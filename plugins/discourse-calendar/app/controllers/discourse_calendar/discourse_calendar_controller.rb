# frozen_string_literal: true

module DiscourseCalendar
  class DiscourseCalendarController < ::ApplicationController
    requires_plugin DiscourseCalendar::PLUGIN_NAME
    before_action :ensure_calendar_enabled

    private

    def ensure_calendar_enabled
      raise Discourse::NotFound if !SiteSetting.calendar_enabled
    end
  end
end
