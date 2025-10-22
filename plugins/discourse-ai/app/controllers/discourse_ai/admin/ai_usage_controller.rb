# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiUsageController < ::Admin::AdminController
      requires_plugin "discourse-ai"

      def show
      end

      def report
        render json: AiUsageSerializer.new(create_report, root: false)
      end

      private

      def create_report
        user_timezone = params[:timezone] || Time.zone.name
        start_date = parse_date_in_timezone(params[:start_date], user_timezone) || 30.days.ago
        end_date = parse_date_in_timezone(params[:end_date], user_timezone) || Time.current

        report =
          DiscourseAi::Completions::Report.new(
            start_date: start_date,
            end_date: end_date,
            timezone: user_timezone,
          )

        report = report.filter_by_feature(params[:feature]) if params[:feature].present?
        report = report.filter_by_model(params[:model]) if params[:model].present?
        report
      end

      def parse_date_in_timezone(date_string, timezone)
        return nil unless date_string

        # Parse date string in user's timezone
        Time.zone = timezone
        Time.zone.parse(date_string)
      rescue StandardError
        nil
      ensure
        Time.zone = nil # Reset to default
      end
    end
  end
end
