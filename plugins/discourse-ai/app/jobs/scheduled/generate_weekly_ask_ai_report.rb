# frozen_string_literal: true

module Jobs
  class GenerateWeeklyAskAiReport < ::Jobs::Scheduled
    every 1.week

    def execute(_args)
      unless SiteSetting.discourse_ai_enabled && SiteSetting.ai_ask_ai_enabled &&
               SiteSetting.ai_ask_ai_report_weekly_enabled
        return
      end

      end_date = Date.yesterday
      start_date = end_date - 6
      unless AskAiLog
               .for_reports
               .where(asked_at: start_date.beginning_of_day..end_date.end_of_day)
               .exists?
        return
      end

      DiscourseAi::AdminDashboard::AskAiReportRequest.call(
        user: Discourse.system_user,
        start_date:,
        end_date:,
        send_to_groups: true,
      )
    end
  end
end
