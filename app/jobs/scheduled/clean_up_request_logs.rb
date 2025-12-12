# frozen_string_literal: true

module Jobs
  class CleanUpRequestLogs < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      clean_browser_page_views if SiteSetting.enable_page_view_logging
      clean_api_request_logs if SiteSetting.enable_api_request_logging
    end

    private

    def clean_browser_page_views
      cutoff = SiteSetting.page_view_logging_retention_days.days.ago
      BrowserPageView.where("created_at < ?", cutoff).delete_all
    end

    def clean_api_request_logs
      cutoff = SiteSetting.api_request_logging_retention_days.days.ago
      ApiRequestLog.where("created_at < ?", cutoff).delete_all
    end
  end
end
