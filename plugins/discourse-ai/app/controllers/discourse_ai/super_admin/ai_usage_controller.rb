# frozen_string_literal: true

module DiscourseAi
  module SuperAdmin
    class AiUsageController < ::SuperAdmin::SuperAdminController
      requires_plugin "discourse-ai"

      def show
      end

      def report
        render json: AiUsageSerializer.new(create_report, root: false)
      end

      private

      def create_report
        user_timezone = params[:timezone] || Time.zone.name
        start_date =
          parse_date_in_timezone(params[:start_date], user_timezone, boundary: :beginning) ||
            30.days.ago
        end_date =
          parse_date_in_timezone(params[:end_date], user_timezone, boundary: :end) || Time.current

        report =
          DiscourseAi::Completions::Report.new(
            start_date: start_date,
            end_date: end_date,
            timezone: user_timezone,
            exact_range: true,
          )

        report = report.filter_by_feature(params[:feature]) if params[:feature].present?
        report = report.filter_by_model(params[:model]) if params[:model].present?
        report
      end

      def parse_date_in_timezone(date_string, timezone, boundary: nil)
        return nil unless date_string

        # Parse date string in user's timezone
        Time.zone = timezone
        parsed_date = Time.zone.parse(date_string)

        if date_string.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
          boundary == :end ? parsed_date.end_of_day : parsed_date.beginning_of_day
        else
          parsed_date
        end
      rescue StandardError
        nil
      ensure
        Time.zone = nil # Reset to default
      end
    end
  end
end
