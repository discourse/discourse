# frozen_string_literal: true

module Admin::DiscourseCalendar
  class AdminHolidaysController < Admin::AdminController
    requires_plugin DiscourseCalendar::PLUGIN_NAME

    def index
      region_code = params[:region_code]

      begin
        holidays = DiscourseCalendar::Holiday.find_holidays_for(region_code: region_code)
      rescue Holidays::InvalidRegion
        return(
          render_json_error(
            I18n.t("system_messages.discourse_calendar_holiday_region_invalid"),
            422,
          )
        )
      end

      render json: { region_code: region_code, holidays: holidays }
    end

    def disable
      DiscourseCalendar::DisabledHoliday.create!(disabled_holiday_params)
      CalendarEvent.destroy_by(
        description: disabled_holiday_params[:holiday_name],
        region: disabled_holiday_params[:region_code],
      )

      render json: success_json
    end

    def enable
      if DiscourseCalendar::DisabledHoliday.destroy_by(disabled_holiday_params).present?
        render json: success_json
      else
        render_json_error(I18n.t("system_messages.discourse_calendar_enable_holiday_failed"), 422)
      end
    end

    private

    def disabled_holiday_params
      params.require(:disabled_holiday).permit(:holiday_name, :region_code)
    end
  end
end
