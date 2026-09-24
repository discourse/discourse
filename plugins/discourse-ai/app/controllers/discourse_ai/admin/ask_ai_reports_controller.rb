# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AskAiReportsController < ::Admin::AdminController
      requires_plugin "discourse-ai"
      before_action :ensure_ask_enabled

      def index
        AskAiReport.expire_stale!
        reports = AskAiReport.order(created_at: :desc).limit(3).preload(:subjects, :topic)
        render json: {
                 reports: reports.map { |report| serialize_report(report) },
                 data_explorer_query_id:
                   defined?(DiscourseDataExplorer) && SiteSetting.data_explorer_enabled ? -47 : nil,
                 recipient_groups:
                   Group
                     .where(id: SiteSetting.ai_ask_ai_report_recipient_groups.split("|"))
                     .order(:name)
                     .pluck(:name),
               }
      end

      def asks
        report = AskAiReport.find(params[:report_id])
        subject = report.subjects.find(params[:subject_id])
        latest_ids = subject.ask_ai_logs.select("MAX(ask_ai_logs.id)").group(:query)
        logs = AskAiLog.where(id: latest_ids).order(id: :desc)
        if params[:before].present?
          cursor = params[:before].to_s
          unless cursor.match?(/\A[1-9][0-9]{0,18}\z/) && cursor.to_i <= 9_223_372_036_854_775_807
            raise Discourse::InvalidParameters.new(:before)
          end
          logs = logs.where("ask_ai_logs.id < ?", cursor.to_i)
        end
        rows = logs.limit(21).pluck(:id, :query, :asked_at)
        render json: {
                 asks: rows.first(20).map { |id, query, asked_at| { id:, query:, asked_at: } },
                 next_before: rows.size > 20 ? rows[19][0] : nil,
               }
      end

      def ask
        report = AskAiReport.find(params[:report_id])
        subject = report.subjects.find(params[:subject_id])
        log = subject.ask_ai_logs.find(params[:id])
        render json: {
                 ask: log.as_json(only: %i[id query asked_at answer answer_title ask_outcome]),
               }
      end

      def create
        RateLimiter.new(current_user, "ask-ai-reports", 10, 1.hour).performed!
        report =
          DiscourseAi::AdminDashboard::AskAiReportRequest.call(
            user: current_user,
            start_date: params.require(:start_date),
            end_date: params.require(:end_date),
            send_to_groups:
              (
                if params.key?(:send_to_groups)
                  ActiveModel::Type::Boolean.new.cast(params[:send_to_groups])
                else
                  false
                end
              ),
          )
        render json: { report: serialize_report(report) }, status: :accepted
      end

      private

      def ensure_ask_enabled
        raise Discourse::NotFound unless SiteSetting.ai_ask_ai_enabled
      end

      def serialize_report(report)
        {
          id: report.id,
          start_date: report.start_date,
          end_date: report.end_date,
          report_status: report.report_status,
          summary: report.summary,
          reported_ask_count: report.reported_ask_count,
          total_ask_count: report.total_ask_count,
          topic_url:
            report.topic && guardian.can_see?(report.topic) ? report.topic.relative_url : nil,
          subjects:
            report.subjects.map do |subject|
              {
                id: subject.id,
                name: subject.name,
                description: subject.description,
                ask_count: subject.ask_count,
              }
            end,
        }
      end
    end
  end
end
