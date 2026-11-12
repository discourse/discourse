# frozen_string_literal: true

module DiscourseAi
  module AdminDashboard
    class AskAiReportRequest
      def self.call(user:, start_date:, end_date:, send_to_groups: false)
        raise Discourse::InvalidAccess unless user&.admin?
        unless SiteSetting.discourse_ai_enabled && SiteSetting.ai_ask_ai_enabled
          raise Discourse::NotFound
        end
        if [true, false].exclude?(send_to_groups)
          raise Discourse::InvalidParameters.new(:send_to_groups)
        end
        begin
          first = Date.iso8601(start_date.to_s)
          last = Date.iso8601(end_date.to_s)
        rescue Date::Error
          raise Discourse::InvalidParameters.new(:date_range)
        end
        raise Discourse::InvalidParameters.new(:date_range) if first > last || first > Date.current
        agent = AiAgent.find_by(id: SiteSetting.ai_ask_ai_report_agent)
        model_id = agent&.default_llm_id.presence || SiteSetting.ai_default_llm_model
        unless agent && LlmModel.exists?(id: model_id)
          raise Discourse::InvalidParameters.new(I18n.t("discourse_ai.ask_ai_reports.no_model"))
        end

        cutoff = [Time.current, last.end_of_day].min
        logs = AskAiLog.for_reports.where(asked_at: first.beginning_of_day..cutoff)
        report = nil
        DistributedMutex.synchronize("ask-ai-report-request-#{first}-#{last}") do
          selected =
            logs
              .select("id, COUNT(*) OVER () AS total_ask_count")
              .order(id: :desc)
              .limit(SiteSetting.ai_ask_ai_report_max_asks)
              .to_a
          if selected.empty?
            raise Discourse::InvalidParameters.new(I18n.t("discourse_ai.ask_ai_reports.no_asks"))
          end
          ids = selected.map(&:id)
          total = selected.first.total_ask_count.to_i
          previous_reports = AskAiReport.where(start_date: first, end_date: last)
          previous_reports =
            if user.id == Discourse::SYSTEM_USER_ID
              previous_reports.where(requested_by_id: Discourse::SYSTEM_USER_ID)
            else
              previous_reports.where.not(requested_by_id: Discourse::SYSTEM_USER_ID)
            end
          previous_reports.expire_stale!
          previous = previous_reports.order(created_at: :desc, id: :desc).first
          if previous && !previous.report_status_failed? && previous.total_ask_count == total &&
               previous.reported_ask_count == ids.size && previous.selected_ask_ids == ids
            return previous
          end
          report =
            AskAiReport.create!(
              start_date: first,
              end_date: last,
              requested_by: user,
              send_to_groups:,
              total_ask_count: total,
              reported_ask_count: ids.size,
              selected_ask_ids: ids,
            )
          begin
            Jobs.enqueue(:generate_ask_ai_report, report_id: report.id)
          rescue StandardError
            report.update!(report_status: :failed)
            raise
          end
        end
        report
      end
    end
  end
end
