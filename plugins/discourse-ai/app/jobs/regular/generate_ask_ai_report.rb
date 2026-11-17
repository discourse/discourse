# frozen_string_literal: true

module Jobs
  class GenerateAskAiReport < ::Jobs::Base
    def execute(args)
      DistributedMutex.synchronize(
        "generate-ask-ai-report-#{args[:report_id]}",
        validity: 20.minutes,
      ) do
        AskAiReport.where(id: args[:report_id]).expire_stale!
        report = AskAiReport.find_by(id: args[:report_id])
        return unless report&.report_status_queued?
        begin
          if report.requested_by_id == Discourse::SYSTEM_USER_ID &&
               !SiteSetting.ai_ask_ai_report_weekly_enabled
            raise Discourse::InvalidAccess
          end
          unless report.requested_by&.admin? && SiteSetting.discourse_ai_enabled &&
                   SiteSetting.ai_ask_ai_enabled
            raise Discourse::InvalidAccess
          end
          report.with_lock do
            return unless report.report_status_queued?
            report.update!(report_status: :running)
          end
          result = DiscourseAi::AdminDashboard::AskAiReportGenerator.new(report).generate
          report.with_lock do
            AskAiReport.where(id: report.id).expire_stale!
            return unless report.reload.report_status_running?
            report.subjects.destroy_all
            result
              .fetch("subjects")
              .sort_by { |subject| -subject.fetch("ask_ids").size }
              .each_with_index do |subject, position|
                record =
                  report.subjects.create!(
                    name: subject.fetch("name"),
                    description: subject.fetch("description"),
                    position:,
                    ask_count: subject.fetch("ask_ids").size,
                  )
                AskAiReportSubjectAsk.insert_all!(
                  subject
                    .fetch("ask_ids")
                    .map do |ask_ai_log_id|
                      { ask_ai_report_subject_id: record.id, ask_ai_log_id: }
                    end,
                )
              end
            post = DiscourseAi::AdminDashboard::AskAiReportPublisher.publish(report, result)
            report.update!(
              summary: result.fetch("summary"),
              topic_id: post&.topic_id,
              report_status: :completed,
            )
          end
        rescue StandardError => error
          AskAiReport.where(id: report.id, report_status: %i[queued running]).update_all(
            report_status: AskAiReport.report_statuses[:failed],
            updated_at: Time.current,
          )
          Discourse.warn_exception(
            error,
            message: "Ask AI report generation failed",
            env: {
              report_id: report.id,
            },
          )
        end
      end
    end
  end
end
