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
        report =
          DiscourseAi::Completions::Report.new(
            start_date: params[:start_date]&.to_date || 30.days.ago,
            end_date: params[:end_date]&.to_date || Time.current,
          )

        report = report.filter_by_feature(params[:feature]) if params[:feature].present?
        report = report.filter_by_model(params[:model]) if params[:model].present?
        report
      end
    end
  end
end
